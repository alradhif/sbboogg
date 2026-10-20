# سبٌوق (Sbog)

## للزملاء: فتح المشروع من GitHub

### 1) الوصول للمستودع
- الرابط: **https://github.com/77Fayy/Sbog1**
- الفرع: **`roaa`** (آخر التحديثات)
- إذا المستودع **خاص**: صاحبة المشروع تضيفكم من GitHub → **Settings → Collaborators**

### 2) تنزيل المشروع
```bash
git clone https://github.com/77Fayy/Sbog1.git
cd Sbog1
git checkout roaa
```

أو من **GitHub Desktop / Xcode → Clone**.

### 3) فتح Xcode
1. افتح الملف: **`sbog 3.xcodeproj`**
2. من الشريط العلوي اختر **Scheme: `sbog3`**
3. اختر **محاكي** أو **آيفونك** (موصول بالماك)
4. **Product → Run** (⌘R)

### 4) التوقيع (Signing) — أول مرة
1. Target **sbog** → **Signing & Capabilities**
2. **Team:** حساب Apple ID الخاص بك (Personal Team)
3. إذا ظهر خطأ على Bundle ID، غيّره لاسم فريد مثل: `com.اسمك.sabouq`

### 5) OpenAI (التصوير بعد الالتقاط)
المفتاح **لا يوجد على GitHub** (عمداً).

```bash
cp Secrets.plist.example Secrets.plist
```

افتح `Secrets.plist` وضع مفتاح API من [platform.openai.com](https://platform.openai.com) في `OPENAI_API_KEY`، ثم **Run** من Xcode.

- **مفتاح واحد للفريق:** نفس المفتاح في `Secrets.plist` لكل مطوّر (الرصيد من حساب صاحب المفتاح)
- **اللاعبون** لا يدخلون مفتاحاً

### 6) ملاحظات
- لا ترفعوا **`Secrets.plist`** على GitHub
- الباوندينق المباشر على الكاميرا يعمل بدون OpenAI (Vision على الجوال)
- إذا ظهر خطأ **PIF transfer session**: أغلق Xcode وافتحه، ثم **Clean Build Folder**
