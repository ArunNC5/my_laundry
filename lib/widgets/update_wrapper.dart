import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';

class UpdateWrapper extends StatefulWidget {
  final Widget child;
  final String androidId;
  final String iOSId;
  final bool forceUpdate; // true = no skip button

  const UpdateWrapper({
    super.key,
    required this.child,
    required this.androidId,
    required this.iOSId,
    this.forceUpdate = false,
  });

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    final newVersion = NewVersionPlus(
      androidId: widget.androidId,
      iOSId: widget.iOSId,
    );

    final status = await newVersion.getVersionStatus();
    if (status == null || status.canUpdate == false) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !widget.forceUpdate,
      builder: (_) => AlertDialog(
        title: const Text("Update Available"),
        content: Text(
          "A new version (${status.storeVersion}) is available.\n"
          "You are using ${status.localVersion}.",
        ),
        actions: [
          if (!widget.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("LATER"),
            ),
          TextButton(
            onPressed: () {
              newVersion.launchAppStore(status.storeVersion);
              if (!widget.forceUpdate) Navigator.pop(context);
            },
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
