# Hướng dẫn Thiết lập và Chia sẻ Debug Keystore cho Đội phát triển Mobile

Tài liệu này hướng dẫn cách tạo, trích xuất thông tin chữ ký (SHA-1/SHA-256) và cấu hình Gradle để toàn bộ các thành viên trong đội phát triển sử dụng chung một chữ ký Debug. Việc này đảm bảo tính năng **Google Sign-In** hoạt động đồng bộ trên thiết bị của tất cả mọi người mà chỉ cần cấu hình Google Cloud Console một lần duy nhất.

---

## 1. Thông tin Keystore đã tạo

File debug keystore chung đã được tạo và lưu trữ trực tiếp trong thư mục dự án tại đường dẫn:  
📂 `05-Development/ventourkid-mobile/android/app/debug.keystore`

### Thông tin chi tiết:
* **Tên file:** `debug.keystore`
* **Mật khẩu Keystore (Store Password):** `android`
* **Alias name (Tên định danh):** `ventourkiddebugkey`
* **Mật khẩu Key (Key Password):** `android`
* **Mã vân tay chứng chỉ (Certificate Fingerprints):**
  * **SHA1:** `77:2D:63:4B:23:10:D6:4E:D6:55:B9:75:59:82:E5:09:79:9D:12:B1`
  * **SHA256:** `87:42:71:69:49:4E:D6:3A:46:D9:1B:70:12:68:4C:CB:4A:B7:57:DE:51:89:25:3A:62:85:6F:BB:6B:99:7F:76`

---

## 2. Các bước thực hiện (Lịch sử tạo & Trích xuất)

### Bước 2.1: Lệnh khởi tạo Keystore
Để tạo ra file keystore này, lệnh sau đã được thực thi trong thư mục `android/app/`:
```bash
keytool -genkey -v -keystore debug.keystore -storepass android -alias ventourkiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=VentourKids, OU=Development, O=VentourKids, L=Hanoi, ST=Hanoi, C=VN"
```

### Bước 2.2: Lệnh trích xuất thông tin SHA-1/SHA-256
Để xem lại mã SHA-1 nhằm mục đích cấu hình trên Google Cloud Console:
```bash
keytool -list -v -keystore debug.keystore -alias ventourkiddebugkey -storepass android
```

---

## 3. Cấu hình Gradle để sử dụng Keystore chung

Trong file `05-Development/ventourkid-mobile/android/app/build.gradle.kts`, cấu hình ký số của dự án đã được cập nhật như sau để trỏ trực tiếp vào file keystore chung:

```kotlin
android {
    ...
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "ventourkiddebugkey"
            keyPassword = "android"
        }
    }
    
    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // Có thể đổi thành release signing config riêng sau này
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
```

---

## 4. Hướng dẫn dành cho các thành viên trong Team

Khi có thành viên mới hoặc khi muốn đồng bộ dự án:

1. **Không cần tạo lại Keystore:**  
   File `debug.keystore` đã được đưa lên Git (sử dụng lệnh `git add -f` để bỏ qua luật `.gitignore`). Các thành viên chỉ cần thực hiện `git pull` để nhận file.

2. **Chạy ứng dụng:**  
   Chạy lệnh `flutter run` bình thường. Ứng dụng sẽ tự động được ký bằng `debug.keystore` chung và có mã SHA-1 khớp với cấu hình Google Cloud.

3. **Cấu hình trên Google Cloud Console:**  
   Người quản trị dự án chỉ cần thêm duy nhất một mã SHA-1 Android Client ID vào Google Cloud Console:
   * **SHA-1:** `77:2D:63:4B:23:10:D6:4E:D6:55:B9:75:59:82:E5:09:79:9D:12:B1`
   * **Package Name:** `com.ventourkids.app`
