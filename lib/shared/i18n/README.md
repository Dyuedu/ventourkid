# Hệ thống i18n (Internationalization) - VentourKid Mobile

## Tổng quan

Hệ thống i18n cho phép chuyển đổi giữa 3 ngôn ngữ: **Tiếng Việt (vi)**, **English (en)**, và **한국어 (ko)**.

### Kiến trúc

```
lib/shared/i18n/
├── app_language.dart          # Language controller (Riverpod StateNotifier)
├── app_localizations.dart     # Translations provider + extension methods
├── language_switcher.dart     # UI language switcher widget
├── translations.dart          # Translation lookup logic
└── README.md                  # Tài liệu này

assets/i18n/
├── vi.json                    # Vietnamese translations (source language)
├── en.json                    # English translations
└── ko.json                    # Korean translations
```

### Cách hoạt động

1. **Ngôn ngữ nguồn (source)** là Tiếng Việt — tất cả code hardcoded strings bằng tiếng Việt.
2. Khi người dùng chọn ngôn ngữ khác (en/ko), hệ thống tra cứu bản dịch trong file JSON.
3. Key tra cứu được normalize (bỏ dấu, lowercase) từ chuỗi tiếng Việt gốc.
4. Nếu không tìm thấy bản dịch, hệ thống trả về chuỗi gốc (tiếng Việt).

---

## Cách sử dụng

### 1. Trong ConsumerWidget (khuyến nghị)

```dart
import '../shared/i18n/app_localizations.dart';

class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('Đăng nhập'))),
      body: Center(
        child: Text(ref.tr('Chưa có dữ liệu')),
      ),
    );
  }
}
```

### 2. Trong ConsumerStatefulWidget

```dart
class MyPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('Đăng nhập'))),
      // ...
    );
  }
}
```

### 3. Trong StatelessWidget (không reactive)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // context.tr() không tự rebuild khi đổi ngôn ngữ
    return Text(context.tr('Đăng nhập'));
  }
}
```

### 4. Trong callbacks / error handlers

```dart
// Sử dụng ref.trRead() để không trigger rebuild
onPressed: () {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ref.trRead('Đã lưu thay đổi.'))),
  );
},
```

---

## Thêm bản dịch mới

### Bước 1: Thêm key vào 3 file JSON

Key phải là chuỗi tiếng Việt đã được normalize (bỏ dấu, lowercase, thay khoảng trắng).

Ví dụ: Chuỗi gốc `"Đã xảy ra lỗi"` → key `"da xay ra loi"`

```json
// assets/i18n/vi.json
"da xay ra loi": "Đã xảy ra lỗi"

// assets/i18n/en.json
"da xay ra loi": "An error occurred"

// assets/i18n/ko.json
"da xay ra loi": "오류가 발생했습니다"
```

### Bước 2: Sử dụng trong code

```dart
Text(ref.tr('Đã xảy ra lỗi'))
```

Hệ thống sẽ tự động:
1. Normalize `"Đã xảy ra lỗi"` → `"da xay ra loi"`
2. Tra cứu key trong catalog của ngôn ngữ hiện tại
3. Trả về bản dịch tương ứng

---

## Quy tắc

1. **Luôn viết chuỗi gốc bằng tiếng Việt** trong code — không dùng key trực tiếp.
2. **Không cần thêm key vào vi.json** nếu chuỗi đã có trong file (chỉ cần thêm en.json và ko.json).
3. **Nếu không có bản dịch**, hệ thống trả về chuỗi gốc (tiếng Việt) — không crash.
4. **Sử dụng `ref.tr()`** trong build() methods để tự rebuild khi đổi ngôn ngữ.
5. **Sử dụng `ref.trRead()`** trong callbacks để tránh rebuild không cần thiết.

---

## Danh sách các file đã tích hợp i18n

### Shared widgets
- `lib/shared/widgets/app_empty_view.dart` ✅
- `lib/shared/widgets/app_error_view.dart` ✅
- `lib/shared/i18n/language_switcher.dart` ✅

### App
- `lib/app/app.dart` ✅ (localization delegates, locale, preload translations)

### Cần tích hợp thêm
- `lib/features/auth/` — login, register, forgot password
- `lib/features/notification/` — notification list, detail
- `lib/features/guide/` — guide dashboard, itinerary
- `lib/features/attendance/` — attendance tracking
- `lib/features/incident/` — incident reporting
- `lib/features/livestream/` — live streaming
- Và các feature modules khác...

---

## Kiểm tra

Để kiểm tra hệ thống i18n:

1. Chạy app: `flutter run`
2. Mở trang đăng nhập
3. Bấm icon ngôn ngữ (🌐) ở góc trên bên phải
4. Chọn English / 한국어 / Tiếng Việt
5. UI sẽ tự động chuyển ngôn ngữ