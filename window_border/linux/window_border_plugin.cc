#include "include/window_border/window_border_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cmath>
#include <cstdint>
#include <cstring>

#include "window_border_plugin_private.h"

#define WINDOW_BORDER_PLUGIN(obj)                                      \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), window_border_plugin_get_type(),  \
                              WindowBorderPlugin))

struct _WindowBorderPlugin {
  GObject parent_instance;

  FlView* view;
  FlMethodChannel* channel;
  GtkWindow* window;
  GtkWidget* original_titlebar;
  GtkCssProvider* css_provider;
  gulong window_state_signal;

  gboolean enabled;
  gboolean has_original_state;
  gboolean original_decorated;
  gboolean original_resizable;
  gint original_margin_start;
  gint original_margin_end;
  gint original_margin_top;
  gint original_margin_bottom;

  gdouble border_width;
  gdouble corner_radius;
  gdouble resize_border_width;
  gboolean resizable;
  gboolean shadow_enabled;
  guint32 border_color;
  guint32 background_color;
  gchar* last_state;
};

G_DEFINE_TYPE(WindowBorderPlugin, window_border_plugin, g_object_get_type())

static FlMethodResponse* success_response(FlValue* value = nullptr) {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
}

static FlMethodResponse* error_response(const gchar* code,
                                        const gchar* message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
}

static FlValue* lookup(FlValue* map, const gchar* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(map, key);
}

static gboolean read_number(FlValue* value, gdouble* result) {
  if (value == nullptr) {
    return FALSE;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    *result = fl_value_get_float(value);
    return TRUE;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    *result = static_cast<gdouble>(fl_value_get_int(value));
    return TRUE;
  }
  return FALSE;
}

static const gchar* current_state(WindowBorderPlugin* self) {
  if (self->window == nullptr) {
    return "unknown";
  }
  GdkWindow* gdk_window =
      gtk_widget_get_window(GTK_WIDGET(self->window));
  if (gdk_window == nullptr) {
    return "normal";
  }
  const GdkWindowState state = gdk_window_get_state(gdk_window);
  if ((state & GDK_WINDOW_STATE_ICONIFIED) != 0) {
    return "minimized";
  }
  if ((state & GDK_WINDOW_STATE_FULLSCREEN) != 0) {
    return "fullscreen";
  }
  if ((state & GDK_WINDOW_STATE_MAXIMIZED) != 0) {
    return "maximized";
  }
  return "normal";
}

static void notify_state(WindowBorderPlugin* self) {
  const gchar* state = current_state(self);
  if (g_strcmp0(state, self->last_state) == 0) {
    return;
  }
  g_free(self->last_state);
  self->last_state = g_strdup(state);
  if (self->channel != nullptr) {
    g_autoptr(FlValue) argument = fl_value_new_string(state);
    fl_method_channel_invoke_method(self->channel, "windowStateChanged",
                                    argument, nullptr, nullptr, nullptr);
  }
}

static gboolean window_state_event_cb(GtkWidget* widget,
                                      GdkEventWindowState* event,
                                      gpointer user_data) {
  notify_state(WINDOW_BORDER_PLUGIN(user_data));
  return FALSE;
}

static gboolean ensure_window(WindowBorderPlugin* self, gchar** error) {
  if (self->window != nullptr) {
    return TRUE;
  }
  if (self->view == nullptr) {
    *error = g_strdup("Flutter did not provide a native view for this engine.");
    return FALSE;
  }
  GtkWidget* top_level =
      gtk_widget_get_toplevel(GTK_WIDGET(self->view));
  if (!GTK_IS_WINDOW(top_level)) {
    *error = g_strdup(
        "The Flutter view is not attached to a top-level window yet.");
    return FALSE;
  }
  self->window = GTK_WINDOW(top_level);
  g_object_add_weak_pointer(G_OBJECT(self->window),
                            reinterpret_cast<gpointer*>(&self->window));
  self->window_state_signal =
      g_signal_connect(self->window, "window-state-event",
                       G_CALLBACK(window_state_event_cb), self);
  return TRUE;
}

static void remove_border_css(WindowBorderPlugin* self) {
  if (self->window != nullptr && self->css_provider != nullptr) {
    GtkStyleContext* context =
        gtk_widget_get_style_context(GTK_WIDGET(self->window));
    gtk_style_context_remove_provider(
        context, GTK_STYLE_PROVIDER(self->css_provider));
    gtk_style_context_remove_class(context, "window-border-host");
  }
  g_clear_object(&self->css_provider);
}

static void update_border_visual(WindowBorderPlugin* self) {
  if (!self->enabled || self->window == nullptr) {
    return;
  }
  const gint inset =
      MAX(0, static_cast<gint>(std::round(self->border_width)));
  gtk_widget_set_margin_start(GTK_WIDGET(self->view), inset);
  gtk_widget_set_margin_end(GTK_WIDGET(self->view), inset);
  gtk_widget_set_margin_top(GTK_WIDGET(self->view), inset);
  gtk_widget_set_margin_bottom(GTK_WIDGET(self->view), inset);

  remove_border_css(self);
  const guint red = (self->border_color >> 16) & 0xFF;
  const guint green = (self->border_color >> 8) & 0xFF;
  const guint blue = self->border_color & 0xFF;
  const guint background_red = (self->background_color >> 16) & 0xFF;
  const guint background_green = (self->background_color >> 8) & 0xFF;
  const guint background_blue = self->background_color & 0xFF;
  const gint radius =
      MAX(0, static_cast<gint>(std::round(self->corner_radius)));
  const gchar* shadow = self->shadow_enabled
                            ? ", 0 8px 24px rgba(0, 0, 0, 0.35)"
                            : "";
  g_autofree gchar* css = g_strdup_printf(
      ".window-border-host { background-color: rgb(%u, %u, %u); "
      "border-radius: %dpx; box-shadow: inset 0 0 0 %dpx "
      "rgb(%u, %u, %u)%s; }",
      background_red, background_green, background_blue, radius, inset, red,
      green, blue, shadow);
  self->css_provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(self->css_provider, css, -1, nullptr);
  GtkStyleContext* context =
      gtk_widget_get_style_context(GTK_WIDGET(self->window));
  gtk_style_context_add_class(context, "window-border-host");
  gtk_style_context_add_provider(
      context, GTK_STYLE_PROVIDER(self->css_provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
  gtk_widget_queue_draw(GTK_WIDGET(self->window));
}

static gboolean update_style(WindowBorderPlugin* self,
                             FlValue* arguments,
                             gchar** error) {
  if (arguments == nullptr ||
      fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    *error = g_strdup("Expected a style map.");
    return FALSE;
  }

  if (FlValue* value = lookup(arguments, "borderWidth")) {
    gdouble width = 0;
    if (!read_number(value, &width) || !std::isfinite(width) || width < 0) {
      *error =
          g_strdup("borderWidth must be a finite non-negative number.");
      return FALSE;
    }
    self->border_width = width;
  }
  if (FlValue* value = lookup(arguments, "resizeBorderWidth")) {
    gdouble width = 0;
    if (!read_number(value, &width) || !std::isfinite(width) || width < 0) {
      *error = g_strdup(
          "resizeBorderWidth must be a finite non-negative number.");
      return FALSE;
    }
    self->resize_border_width = width;
  }
  if (FlValue* value = lookup(arguments, "cornerRadius")) {
    gdouble radius = 0;
    if (!read_number(value, &radius) || !std::isfinite(radius) ||
        radius < 0) {
      *error =
          g_strdup("cornerRadius must be a finite non-negative number.");
      return FALSE;
    }
    self->corner_radius = radius;
  }
  if (FlValue* value = lookup(arguments, "borderColor")) {
    if (fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
      *error = g_strdup("borderColor must be a 32-bit ARGB integer.");
      return FALSE;
    }
    const gint64 color = fl_value_get_int(value);
    if (color < 0 || color > G_MAXUINT32) {
      *error = g_strdup("borderColor must be a 32-bit ARGB integer.");
      return FALSE;
    }
    self->border_color = static_cast<guint32>(color);
  }
  if (FlValue* value = lookup(arguments, "backgroundColor")) {
    if (fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
      *error = g_strdup("backgroundColor must be a 32-bit ARGB integer.");
      return FALSE;
    }
    const gint64 color = fl_value_get_int(value);
    if (color < 0 || color > G_MAXUINT32) {
      *error = g_strdup("backgroundColor must be a 32-bit ARGB integer.");
      return FALSE;
    }
    self->background_color = static_cast<guint32>(color);
  }
  if (FlValue* value = lookup(arguments, "resizable")) {
    if (fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
      *error = g_strdup("resizable must be a boolean.");
      return FALSE;
    }
    self->resizable = fl_value_get_bool(value);
  }
  if (FlValue* value = lookup(arguments, "shadowEnabled")) {
    if (fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
      *error = g_strdup("shadowEnabled must be a boolean.");
      return FALSE;
    }
    self->shadow_enabled = fl_value_get_bool(value);
  }

  if (self->enabled) {
    gtk_window_set_resizable(self->window, self->resizable);
    update_border_visual(self);
  }
  return TRUE;
}

static gboolean set_enabled(WindowBorderPlugin* self,
                            gboolean enabled,
                            gchar** error) {
  if (enabled == self->enabled) {
    if (enabled) {
      update_border_visual(self);
    }
    return TRUE;
  }
  if (enabled && !ensure_window(self, error)) {
    return FALSE;
  }

  if (enabled) {
    self->has_original_state = TRUE;
    self->original_decorated = gtk_window_get_decorated(self->window);
    self->original_resizable = gtk_window_get_resizable(self->window);
    self->original_margin_start =
        gtk_widget_get_margin_start(GTK_WIDGET(self->view));
    self->original_margin_end =
        gtk_widget_get_margin_end(GTK_WIDGET(self->view));
    self->original_margin_top =
        gtk_widget_get_margin_top(GTK_WIDGET(self->view));
    self->original_margin_bottom =
        gtk_widget_get_margin_bottom(GTK_WIDGET(self->view));
    GtkWidget* titlebar = gtk_window_get_titlebar(self->window);
    if (titlebar != nullptr) {
      self->original_titlebar = GTK_WIDGET(g_object_ref(titlebar));
    }

    self->enabled = TRUE;
    gtk_window_set_titlebar(self->window, nullptr);
    gtk_window_set_decorated(self->window, FALSE);
    gtk_window_set_resizable(self->window, self->resizable);
    update_border_visual(self);
  } else {
    self->enabled = FALSE;
    remove_border_css(self);
    if (self->window != nullptr && self->has_original_state) {
      gtk_widget_set_margin_start(GTK_WIDGET(self->view),
                                  self->original_margin_start);
      gtk_widget_set_margin_end(GTK_WIDGET(self->view),
                                self->original_margin_end);
      gtk_widget_set_margin_top(GTK_WIDGET(self->view),
                                self->original_margin_top);
      gtk_widget_set_margin_bottom(GTK_WIDGET(self->view),
                                   self->original_margin_bottom);
      gtk_window_set_titlebar(self->window, self->original_titlebar);
      gtk_window_set_decorated(self->window, self->original_decorated);
      gtk_window_set_resizable(self->window, self->original_resizable);
    }
    g_clear_object(&self->original_titlebar);
    self->has_original_state = FALSE;
  }
  return TRUE;
}

static gboolean pointer_position(WindowBorderPlugin* self,
                                 gint* root_x,
                                 gint* root_y) {
  GdkWindow* gdk_window =
      gtk_widget_get_window(GTK_WIDGET(self->window));
  if (gdk_window == nullptr) {
    return FALSE;
  }
  GdkDisplay* display = gdk_window_get_display(gdk_window);
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = seat == nullptr ? nullptr : gdk_seat_get_pointer(seat);
  if (pointer == nullptr) {
    return FALSE;
  }
  gdk_device_get_position(pointer, nullptr, root_x, root_y);
  return TRUE;
}

static gboolean resize_edge_from_name(const gchar* name,
                                      GdkWindowEdge* edge) {
  if (g_strcmp0(name, "left") == 0) {
    *edge = GDK_WINDOW_EDGE_WEST;
  } else if (g_strcmp0(name, "top") == 0) {
    *edge = GDK_WINDOW_EDGE_NORTH;
  } else if (g_strcmp0(name, "right") == 0) {
    *edge = GDK_WINDOW_EDGE_EAST;
  } else if (g_strcmp0(name, "bottom") == 0) {
    *edge = GDK_WINDOW_EDGE_SOUTH;
  } else if (g_strcmp0(name, "topLeft") == 0) {
    *edge = GDK_WINDOW_EDGE_NORTH_WEST;
  } else if (g_strcmp0(name, "topRight") == 0) {
    *edge = GDK_WINDOW_EDGE_NORTH_EAST;
  } else if (g_strcmp0(name, "bottomLeft") == 0) {
    *edge = GDK_WINDOW_EDGE_SOUTH_WEST;
  } else if (g_strcmp0(name, "bottomRight") == 0) {
    *edge = GDK_WINDOW_EDGE_SOUTH_EAST;
  } else {
    return FALSE;
  }
  return TRUE;
}

static FlMethodResponse* window_border_plugin_handle_method_call(
    WindowBorderPlugin* self,
    FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* arguments = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    return get_platform_version();
  }

  g_autofree gchar* error = nullptr;
  if (strcmp(method, "initialize") == 0) {
    if (!update_style(self, arguments, &error)) {
      return error_response("invalid_arguments", error);
    }
    FlValue* enabled_value = lookup(arguments, "enabled");
    const gboolean enabled =
        enabled_value == nullptr ? TRUE : fl_value_get_bool(enabled_value);
    if (enabled_value != nullptr &&
        fl_value_get_type(enabled_value) != FL_VALUE_TYPE_BOOL) {
      return error_response("invalid_arguments", "enabled must be a boolean.");
    }
    if (!ensure_window(self, &error)) {
      return error_response("window_unavailable", error);
    }
    if (!set_enabled(self, enabled, &error)) {
      return error_response("window_unavailable", error);
    }
    notify_state(self);
    return success_response();
  }

  if (strcmp(method, "setEnabled") == 0) {
    if (arguments == nullptr ||
        fl_value_get_type(arguments) != FL_VALUE_TYPE_BOOL) {
      return error_response("invalid_arguments",
                            "setEnabled expects a boolean.");
    }
    if (!set_enabled(self, fl_value_get_bool(arguments), &error)) {
      return error_response("window_unavailable", error);
    }
    return success_response();
  }

  if (strcmp(method, "setStyle") == 0) {
    if (!update_style(self, arguments, &error)) {
      return error_response("invalid_arguments", error);
    }
    return success_response();
  }

  if (!ensure_window(self, &error)) {
    return error_response("window_unavailable", error);
  }

  if (strcmp(method, "startDragging") == 0) {
    gint root_x = 0;
    gint root_y = 0;
    if (pointer_position(self, &root_x, &root_y)) {
      gtk_window_begin_move_drag(self->window, 1, root_x, root_y,
                                 gtk_get_current_event_time());
    }
    return success_response();
  }
  if (strcmp(method, "startResizing") == 0) {
    if (arguments == nullptr ||
        fl_value_get_type(arguments) != FL_VALUE_TYPE_STRING) {
      return error_response("invalid_arguments", "Unknown resize edge.");
    }
    GdkWindowEdge edge = GDK_WINDOW_EDGE_NORTH;
    if (!resize_edge_from_name(fl_value_get_string(arguments), &edge)) {
      return error_response("invalid_arguments", "Unknown resize edge.");
    }
    gint root_x = 0;
    gint root_y = 0;
    if (self->resizable && pointer_position(self, &root_x, &root_y)) {
      gtk_window_begin_resize_drag(self->window, edge, 1, root_x, root_y,
                                   gtk_get_current_event_time());
    }
    return success_response();
  }
  if (strcmp(method, "minimize") == 0) {
    gtk_window_iconify(self->window);
    return success_response();
  }
  if (strcmp(method, "maximize") == 0) {
    gtk_window_maximize(self->window);
    return success_response();
  }
  if (strcmp(method, "restore") == 0) {
    gtk_window_deiconify(self->window);
    gtk_window_unmaximize(self->window);
    return success_response();
  }
  if (strcmp(method, "toggleMaximize") == 0) {
    if (g_strcmp0(current_state(self), "maximized") == 0) {
      gtk_window_unmaximize(self->window);
    } else {
      gtk_window_maximize(self->window);
    }
    return success_response();
  }
  if (strcmp(method, "close") == 0) {
    gtk_window_close(self->window);
    return success_response();
  }
  if (strcmp(method, "isMaximized") == 0) {
    g_autoptr(FlValue) value = fl_value_new_bool(
        g_strcmp0(current_state(self), "maximized") == 0);
    return success_response(value);
  }
  if (strcmp(method, "getState") == 0) {
    g_autoptr(FlValue) value = fl_value_new_string(current_state(self));
    return success_response(value);
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version =
      g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return success_response(result);
}

static void window_border_plugin_dispose(GObject* object) {
  WindowBorderPlugin* self = WINDOW_BORDER_PLUGIN(object);
  if (self->enabled) {
    g_autofree gchar* ignored_error = nullptr;
    set_enabled(self, FALSE, &ignored_error);
  }
  if (self->window != nullptr) {
    if (self->window_state_signal != 0) {
      g_signal_handler_disconnect(self->window, self->window_state_signal);
      self->window_state_signal = 0;
    }
    g_object_remove_weak_pointer(
        G_OBJECT(self->window), reinterpret_cast<gpointer*>(&self->window));
    self->window = nullptr;
  }
  remove_border_css(self);
  g_clear_object(&self->original_titlebar);
  g_clear_object(&self->view);
  self->channel = nullptr;
  g_clear_pointer(&self->last_state, g_free);
  G_OBJECT_CLASS(window_border_plugin_parent_class)->dispose(object);
}

static void window_border_plugin_class_init(WindowBorderPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = window_border_plugin_dispose;
}

static void window_border_plugin_init(WindowBorderPlugin* self) {
  self->border_width = 1.0;
  self->corner_radius = 0.0;
  self->resize_border_width = 8.0;
  self->resizable = TRUE;
  self->shadow_enabled = TRUE;
  self->border_color = 0xFF3C4043;
  self->background_color = 0xFF000000;
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  WindowBorderPlugin* plugin = WINDOW_BORDER_PLUGIN(user_data);
  g_autoptr(FlMethodResponse) response =
      window_border_plugin_handle_method_call(plugin, method_call);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to window_border call: %s", error->message);
  }
}

void window_border_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  WindowBorderPlugin* plugin = WINDOW_BORDER_PLUGIN(
      g_object_new(window_border_plugin_get_type(), nullptr));
  FlView* view = fl_plugin_registrar_get_view(registrar);
  if (view != nullptr) {
    plugin->view = FL_VIEW(g_object_ref(view));
  }

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "window_border", FL_METHOD_CODEC(codec));
  plugin->channel = channel;
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  g_object_unref(plugin);
}
