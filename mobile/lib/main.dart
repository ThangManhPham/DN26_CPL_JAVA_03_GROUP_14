import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'data/auth_repository.dart';
import 'data/photo_repository.dart';
import 'firebase_options.dart';
import 'ios_widget_bridge.dart';
import 'photo_screen.dart';
import 'push_bridge.dart';
import 'theme.dart';

const _mock = bool.fromEnvironment('OURSPACE_USE_MOCK');
const _configuredBaseUrl = String.fromEnvironment('OURSPACE_API_BASE_URL');
String get _baseUrl => _configuredBaseUrl.isNotEmpty
    ? _configuredBaseUrl
    : 'http://localhost:8080';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  PushBridge? push;
  if (!_mock) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_backgroundPushHandler);
    push = PushBridge(baseUrl: _baseUrl, messengerKey: messengerKey);
  }
  // Auth is memory-only until M2 adds secure session persistence.
  await IosWidgetBridge.clear();
  runApp(
    OurSpaceApp(
      repository: _mock
          ? MockAuthRepository()
          : HttpAuthRepository(baseUrl: _baseUrl),
      photoRepository: _mock
          ? MockPhotoRepository()
          : HttpPhotoRepository(baseUrl: _baseUrl),
      push: push,
      messengerKey: messengerKey,
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _backgroundPushHandler(RemoteMessage message) async {
  // The notification payload is displayed by the OS. Do not fetch private
  // photos here: the user may have logged out while the app was terminated.
}

class OurSpaceApp extends StatefulWidget {
  const OurSpaceApp({
    super.key,
    required this.repository,
    this.photoRepository,
    this.push,
    this.messengerKey,
  });
  final AuthRepository repository;
  final PhotoRepository? photoRepository;
  final PushBridge? push;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  @override
  State<OurSpaceApp> createState() => _OurSpaceAppState();
}

class _OurSpaceAppState extends State<OurSpaceApp> {
  AuthSession? _session;
  bool _profile = false;
  late final PhotoRepository _photos =
      widget.photoRepository ?? MockPhotoRepository();

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: widget.messengerKey,
    title: 'OurSpace',
    debugShowCheckedModeBanner: false,
    theme: ourSpaceTheme,
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: _session == null
        ? AuthScreen(
            repository: widget.repository,
            onAuthenticated: (session) {
              setState(() => _session = session);
              widget.push?.activate(session.token);
            },
          )
        : _profile
        ? ProfileScreen(
            repository: widget.repository,
            session: _session!,
            onRefreshed: (user) =>
                setState(() => _session = _session!.withUser(user)),
            onBack: () => setState(() => _profile = false),
            onSaved: (user) => setState(() {
              _session = _session!.withUser(user);
              _profile = false;
            }),
            onLogout: () {
              widget.push?.deactivate(_session!.token);
              IosWidgetBridge.clear();
              setState(() {
                _session = null;
                _profile = false;
              });
            },
          )
        : HomeScreen(
            user: _session!.user,
            token: _session!.token,
            photos: _photos,
            onProfile: () => setState(() => _profile = true),
          ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.repository,
    required this.onAuthenticated,
  });
  final AuthRepository repository;
  final ValueChanged<AuthSession> onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(bool register) {
    if (_busy || _register == register) return;
    setState(() {
      _register = register;
      _error = null;
      _form.currentState?.reset();
      _password.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = _register
          ? await widget.repository.register(
              _email.text.trim(),
              _password.text,
              _name.text.trim(),
            )
          : await widget.repository.login(_email.text.trim(), _password.text);
      if (mounted) widget.onAuthenticated(session);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const BrandMark(),
              const SizedBox(height: 46),
              Text(
                _register
                    ? 'Tạo không gian\ncho hai người.'
                    : 'Chào mừng\ntrở lại.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                _register
                    ? 'Bắt đầu lưu những khoảnh khắc chỉ hai bạn nhìn thấy.'
                    : 'Những điều thân thuộc đang đợi bạn ở đây.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Đăng nhập')),
                  ButtonSegment(value: true, label: Text('Đăng ký')),
                ],
                selected: {_register},
                showSelectedIcon: false,
                onSelectionChanged: (value) => _switchMode(value.first),
              ),
              const SizedBox(height: 28),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_register) ...[
                      TextFormField(
                        key: const Key('displayNameField'),
                        controller: _name,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                        ),
                        validator: validateDisplayName,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const Key('emailField'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('passwordField'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        helperText: _register ? 'Ít nhất 8 ký tự' : null,
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Ẩn mật khẩu'
                              : 'Hiện mật khẩu',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          validatePassword(value, registering: _register),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const Key('authError'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      key: const Key('authSubmit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Tạo tài khoản' : 'Đăng nhập'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              const Center(child: Text('Một nơi riêng cho những điều chung.')),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.token,
    required this.photos,
    required this.onProfile,
  });
  final UserProfile user;
  final String token;
  final PhotoRepository photos;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Row(
                children: [
                  const Expanded(child: BrandMark()),
                  IconButton(
                    key: const Key('openProfile'),
                    tooltip: 'Mở hồ sơ',
                    onPressed: onProfile,
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ),
              const SizedBox(height: 62),
              Text(
                'Chào ${user.displayName},',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Không gian của bạn bắt đầu từ đây.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.softRose,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.favorite_outline,
                      size: 40,
                      color: AppColors.rose,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cùng nhau tạo nên\nOurSpace',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Khi hai bạn kết nối, những kỷ niệm chung sẽ xuất hiện ở đây.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('openPhotos'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoScreen(
                      repository: photos,
                      token: token,
                      userId: user.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Ảnh của hai bạn'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onRefreshed,
    required this.onSaved,
    required this.onBack,
    required this.onLogout,
  });
  final AuthRepository repository;
  final AuthSession session;
  final ValueChanged<UserProfile> onRefreshed;
  final ValueChanged<UserProfile> onSaved;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.session.user.displayName);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final user = await widget.repository.getProfile(widget.session.token);
      if (!mounted) return;
      if (_name.text == widget.session.user.displayName) {
        _name.text = user.displayName;
      }
      widget.onRefreshed(user);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải hồ sơ mới nhất.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.repository.updateProfile(
        widget.session.token,
        _name.text.trim(),
      );
      if (mounted) widget.onSaved(user);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể lưu hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Hồ sơ của tôi'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.softRose,
                child: Text(
                  widget.session.user.displayName.characters.first
                      .toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppColors.rose),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Thông tin cá nhân',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tên này sẽ hiển thị trong không gian chung của hai bạn.',
              ),
              const SizedBox(height: 28),
              Form(
                key: _form,
                child: TextFormField(
                  key: const Key('profileNameField'),
                  controller: _name,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                  validator: validateDisplayName,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                initialValue: widget.session.user.email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email hiện chưa thể thay đổi',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('profileError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('saveProfile'),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu thay đổi'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _busy ? null : widget.onLogout,
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.favorite, color: AppColors.rose, size: 28),
      const SizedBox(width: 8),
      Text('ourspace', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Vui lòng nhập tên hiển thị.';
  if (name.length < 2 || name.length > 40) return 'Tên cần từ 2 đến 40 ký tự.';
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Vui lòng nhập email.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Email chưa đúng định dạng.';
  }
  return null;
}

String? validatePassword(String? value, {required bool registering}) {
  if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
  if (registering && value.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
  return null;
}
