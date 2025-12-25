import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/group_invite_link.dart';
import '../models/user.dart';
import '../services/calendar_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/nurse_button.dart';
import '../widgets/nurse_text_field.dart';

class InvitePreviewPage extends StatefulWidget {
  const InvitePreviewPage({
    super.key,
    required this.token,
    required this.apiClient,
    required this.currentUser,
    required this.onLogin,
    required this.onJoined,
  });

  final String token;
  final CalendarApiClient apiClient;
  final User? currentUser;
  final Future<void> Function(AuthSession session) onLogin;
  final Future<void> Function(String groupId) onJoined;

  @override
  State<InvitePreviewPage> createState() => _InvitePreviewPageState();
}

class _InvitePreviewPageState extends State<InvitePreviewPage> {
  GroupInvitePreview? _preview;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRedeeming = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final GroupInvitePreview preview =
          await widget.apiClient.fetchInvitePreview(widget.token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载邀请失败: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleJoin() async {
    if (_preview == null || _preview!.valid != true) return;
    if (_isRedeeming) return;
    if (_user == null) {
      final AuthSession? session = await Navigator.of(context).push<AuthSession>(
        MaterialPageRoute(
          builder: (_) => _LoginPage(apiClient: widget.apiClient),
        ),
      );
      if (session == null) return;
      await widget.onLogin(session);
      _user = session.user;
      if (!mounted) return;
    }
    setState(() => _isRedeeming = true);
    try {
      final GroupInviteRedeemResponse response =
          await widget.apiClient.redeemInvite(
        token: widget.token,
        userId: _user!.id.toString(),
      );
      if (!mounted) return;
      if (response.status == 'JOINED' ||
          response.status == 'ALREADY_MEMBER') {
        await widget.onJoined(response.groupId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusMessage(response.status))),
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() => _errorMessage = _statusMessage(response.status));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '加入失败: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isRedeeming = false);
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'JOINED':
        return '已加入群组';
      case 'ALREADY_MEMBER':
        return '你已在该群组中';
      case 'PENDING_APPROVAL':
        return '已提交加入申请';
      case 'INVALID_INVITE':
        return '邀请已失效';
    }
    return '操作失败';
  }

  String _reasonMessage(String? reason) {
    switch (reason) {
      case 'EXPIRED':
        return '邀请链接已过期';
      case 'REVOKED':
        return '邀请已撤销';
      case 'NOT_FOUND':
        return '链接无效或不存在';
      case 'NO_USES_LEFT':
        return '邀请次数已用尽';
      default:
        return '邀请不可用';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请预览')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!);
    }
    if (_preview == null) {
      return const _ErrorState(message: '邀请信息为空');
    }
    if (_preview!.valid != true || _preview!.group == null) {
      return _ErrorState(message: _reasonMessage(_preview!.reason));
    }
    final GroupInvitePreviewGroup group = _preview!.group!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.name, style: AppTextStyles.headingMedium),
        const SizedBox(height: 6),
        Text(
          '成员数：${group.memberCount}',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        if (_preview!.remainingUses != null) ...[
          const SizedBox(height: 4),
          Text(
            '剩余次数：${_preview!.remainingUses}',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: NurseButton(
            label: _isRedeeming ? '处理中...' : '确认加入',
            onPressed: _isRedeeming ? null : _handleJoin,
          ),
        ),
        if (_user == null) ...[
          const SizedBox(height: 12),
          Text(
            '需要登录后才能加入群组',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: AppTextStyles.body),
          const SizedBox(height: 16),
          NurseButton(
            label: '返回',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.apiClient});

  final CalendarApiClient apiClient;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请输入邮箱和密码');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final AuthSession session =
          await widget.apiClient.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '登录失败: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            NurseTextField(
              label: '邮箱',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            NurseTextField(
              label: '密码',
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: _isSubmitting ? '登录中...' : '登录',
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
