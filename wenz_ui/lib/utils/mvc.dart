import 'package:flutter/material.dart';

T? findController<T extends MvcController>(BuildContext context) {
  T? mvcController;
  context.visitAncestorElements((element) {
    var widget = element.widget;
    if (widget is MvcControllerProvider) {
      if (widget.controller is T) {
        mvcController = widget.controller as T;
        return false;
      }
    }
    if (element is StatefulElement) {
      var state = element.state;
      if (state is MvcViewState) {
        var controller = state.widget.controller;
        if (controller is T) {
          mvcController = controller;
          return false;
        }
      }
    }
    return true;
  });
  return mvcController;
}

mixin MvcMixin {
  void onInit(BuildContext context, MvcViewState state);

  void onReplace(BuildContext context, covariant MvcController oldController);

  Future refresh() async {}
}

class MvcControllerProvider extends StatelessWidget {
  final MvcController? controller;
  final Widget child;

  const MvcControllerProvider({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// 也可以封装mvvm，mvp，看看相关文章
class MvcView<T extends MvcController> extends StatefulWidget {
  final T controller;
  final WidgetBuilder? builder;

  const MvcView({
    super.key,
    required this.controller,
    this.builder,
  });

  void onInitState() {}

  Widget build(BuildContext context) {
    return builder?.call(context) ?? Container();
  }

  @override
  State<MvcView> createState() => MvcViewState();
}

class MvcViewState extends State<MvcView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onInitState();
    widget.controller.onInitState(context, this);
    widget.controller.addListener(onChanged);
  }

  void onChanged() {
    try {
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 在build阶段调用会抛出异常，忽略之
      print(e);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(onChanged);
    widget.controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.build(context);
  }

  @override
  void didUpdateWidget(covariant MvcView<MvcController> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.controller, oldWidget.controller)) {
      return;
    }
    oldWidget.controller.removeListener(onChanged);
    widget.controller.addListener(onChanged);
    widget.controller.onDidUpdateWidget(context, oldWidget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.didChangeDependencies();
  }

  @override
  bool get wantKeepAlive => widget.controller.wantKeepAlive;
}

class MvcController with ChangeNotifier {
  bool mounted = false;
  bool isLoading = false;
  final List<VoidCallback> _disposeCallbacks = [];

  bool get wantKeepAlive => false;

  /// 组件初始化时会触发此方法
  @mustCallSuper
  void onInitState(BuildContext context, MvcViewState state) {
    if (this is MvcMixin) {
      var repace = this as MvcMixin;
      repace.onInit(context, state);
    }
  }

  Future<T?> loading<T>(Future<T?> Function() future) async {
    try {
      isLoading = true;
      updateView();
      var result = await future.call();
      return result;
    } catch (e) {
      print(e);
      return null;
    } finally {
      isLoading = false;
      updateView();
    }
  }

  void listen(Listenable listener, void Function() callback) {
    listener.addListener(callback);
    _disposeCallbacks.add(() {
      listener.removeListener(callback);
    });
  }

  void clearListen() {
    for (var callback in _disposeCallbacks) {
      callback.call();
    }
  }

  /// 父节点setState时会触发此方法
  @mustCallSuper
  void onDidUpdateWidget(BuildContext context,
      covariant MvcController oldController) {
    oldController.clearListen();
    isLoading = oldController.isLoading;
    mounted = oldController.mounted;
    if (this is MvcMixin) {
      var repace = this as MvcMixin;
      repace.onReplace(context, oldController);
    }
  }

  /// widget树中，若节点的父级结构中的层级 或 父级结构中的任一节点的widget类型有变化，节点会调用didChangeDependencies；
  /// 若仅仅是父级结构某一节点的widget的某些属性值变化，节点不会调用didChangeDependencies
  @mustCallSuper
  void didChangeDependencies() {
    mounted = true;
  }

  /// 组件关闭时会触发此方法
  @mustCallSuper
  void onDispose() {
    mounted = false;
    for (var callback in _disposeCallbacks) {
      callback.call();
    }
  }

  void updateView() {
    try {
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  static T of<T extends MvcController>(BuildContext context) {
    MvcController? mvcController;
    context.visitAncestorElements((element) {
      if (element is StatefulElement) {
        var state = element.state;
        if (state is MvcViewState) {
          if (state.widget.controller is T) {
            mvcController = state.widget.controller;
            return false;
          }
        }
      }
      return true;
    });
    return mvcController as T;
  }

}

class MvcContextController extends MvcController {
  BuildContext? _context;

  BuildContext get context => _context!;

  @override
  @mustCallSuper
  void onInitState(BuildContext context, MvcViewState state) {
    this._context = context;
    super.onInitState(context, state);
  }

  @override
  @mustCallSuper
  void onDidUpdateWidget(BuildContext context,
      covariant MvcContextController oldController) {
    super.onDidUpdateWidget(context, oldController);
    _context = oldController.context;
  }
}
