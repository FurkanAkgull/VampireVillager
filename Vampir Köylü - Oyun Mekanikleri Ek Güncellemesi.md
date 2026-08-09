# Vampir Köylü - Oyun Mekanikleri Ek Güncellemesi

Mevcut Flutter Vampir Köylü multiplayer oyununa aşağıdaki 3 özelliği ekle:

1. Gece aksiyonlarının sonuçlarının görüntülenmesi
2. Rollerinin server tarafından tamamen random atanması
3. Chat mesaj bildirimleri

Mevcut çalışan UI, backend, WebSocket ve oyun akışını bozma. Mevcut mimariyi inceleyerek gerekli alanları genişlet.

---

# 1. GECE AKSİYONLARI VE SONUÇLARI

En önemli yeni özellik budur.

Gece boyunca oyuncuların gerçekleştirdiği aksiyonlar server tarafından kaydedilmeli.

Gece süresi tamamlandığında server tüm gece aksiyonlarını çözmeli ve bir **Night Resolution** oluşturmalıdır.

Örnek:

```text
GECE 2 BİTTİ

Vampirler:
Ahmet'i hedefledi.

Doktor:
Ahmet'i korudu.

Medyum:
Mehmet'i inceledi.

SONUÇ:

Ahmet hayatta kaldı.
```

Ancak burada gizlilik kurallarına dikkat et.

---

## 1.1 Night Action Log

Server gece boyunca aşağıdaki gibi action kayıtları tutmalı:

```text
NightAction

round
actorPlayerId
actionType
targetPlayerId
createdAt
result
```

Örneğin:

```json
{
  "round": 2,
  "actorPlayerId": "vampire-team",
  "actionType": "KILL",
  "targetPlayerId": "player-123",
  "result": "TARGETED"
}
```

Doctor:

```json
{
  "round": 2,
  "actorPlayerId": "player-456",
  "actionType": "PROTECT",
  "targetPlayerId": "player-123",
  "result": "PROTECTED"
}
```

Medium:

```json
{
  "round": 2,
  "actorPlayerId": "player-789",
  "actionType": "CHECK",
  "targetPlayerId": "player-222",
  "result": "VAMPIRE"
}
```

---

# 1.2 Night Resolution

Gece bittiğinde server:

```text
Resolve Night
```

işlemini gerçekleştirmeli.

Örnek:

```text
Vampire target:
Ahmet

Doctor target:
Ahmet

Result:
Ahmet survived.
```

Server tüm gece aksiyonlarını çözmeden gündüze geçmemeli.

Önerilen sıra:

```text
NIGHT
   ↓
Collect Actions
   ↓
Validate Actions
   ↓
Resolve Vampire Action
   ↓
Resolve Doctor Action
   ↓
Resolve Medium / Seer
   ↓
Resolve Other Roles
   ↓
Calculate Deaths
   ↓
Create Night Resolution
   ↓
Send Results
   ↓
DAY
```

---

# 1.3 Night Result UI

Gece sona erdiğinde oyun doğrudan gündüz ekranına geçmemeli.

Önce kısa bir:

```text
GECE SONUCU
```

ekranı göster.

Örneğin:

```text
┌──────────────────────────────┐
│                              │
│       GECE 2 SONUCU          │
│                              │
│  🧛 Vampirler                │
│  Ahmet'i hedefledi.          │
│                              │
│  🩺 Doktor                   │
│  Ahmet'i korudu.             │
│                              │
│  🔮 Medyum                   │
│  Mehmet'i inceledi.          │
│                              │
│  ✓ Ahmet hayatta kaldı.      │
│                              │
│          [ DEVAM ]           │
└──────────────────────────────┘
```

Bu ekran animasyonlu olabilir.

---

# 1.4 Hangi Aksiyonlar Görünecek?

Burada önemli bir oyun tasarımı kararı var.

Varsayılan olarak **oyuncular birbirlerinin gizli rollerini ve özel aksiyonlarını görmemeli.**

Örneğin normal köylüye:

```text
Vampirler Ahmet'i seçti.
Doktor Ahmet'i korudu.
Medyum Mehmet'i inceledi.
```

şeklinde bütün gizli bilgiler gösterilmemeli.

Normal oyuncuya:

```text
GECE 2 SONUCU

Bu gece bir saldırı gerçekleşti.

Ahmet hayatta kaldı.
```

gösterilebilir.

Ancak **oyun ayarlarında "Detaylı Gece Sonuçları" aktifse** daha detaylı bilgiler gösterilebilir.

Bu özelliği configurable yap.

---

# 1.5 Detaylı Gece Sonuçları

Host tarafından:

```text
Detaylı Gece Sonuçları
[ ON / OFF ]
```

seçeneği bulunabilir.

OFF:

```text
Bu gece bir saldırı gerçekleşti.

Ahmet hayatta kaldı.
```

ON:

```text
Vampirler:
Ahmet'i hedefledi.

Doktor:
Ahmet'i korudu.

Sonuç:
Ahmet hayatta kaldı.
```

Bu ayar server tarafından tutulmalıdır.

Client kendi kendine değiştirememeli.

---

# 1.6 Player-Specific Action Results

Bazı sonuçlar yalnızca ilgili oyuncuya gönderilmeli.

Örneğin Seer:

```text
Sen:
Mehmet'i inceledin.

Sonuç:
MEHMET = VAMPİR
```

Bu bilgi diğer oyunculara gönderilmemeli.

Doctor:

```text
Bu gece:
Ahmet'i korudun.
```

Vampire:

```text
Bu gece:
Ahmet'i hedeflediniz.
```

gibi kendi aksiyonunu görebilir.

---

# 1.7 Night Result WebSocket Event

Yeni event:

```text
NIGHT_RESOLUTION
```

Örnek:

```json
{
  "event": "NIGHT_RESOLUTION",
  "data": {
    "round": 2,
    "summary": {
      "playersDied": [],
      "playersSaved": ["player-123"]
    },
    "actions": []
  }
}
```

`actions` alanı yalnızca o oyuncunun görmesine izin verilen bilgileri içermeli.

Server tarafında global action log tutulabilir ancak client'a bütün global log gönderilmemeli.

---

# 1.8 Gündüz Başlangıcı

Night Resolution tamamlandıktan sonra:

```text
Night Resolution
       ↓
2-5 seconds
       ↓
DAY
```

geçişi yapılmalı.

Örneğin:

```text
GECE SONA ERDİ

...

[ DEVAM ET ]

       ↓

GÜNDÜZ 3
05:00
```

---

# 2. ROLLER RANDOM ATANMALI

Role assignment tamamen server tarafında yapılmalı.

Client hiçbir şekilde rol belirlememeli.

Oyun başladığında:

```text
Players
   ↓
Active Roles
   ↓
Role Pool
   ↓
Secure Random Shuffle
   ↓
Assign Roles
```

uygulanmalı.

---

## 2.1 Örnek

8 oyuncu:

```text
VAMPIRE
VAMPIRE
DOCTOR
MEDIUM
JESTER
VILLAGER
VILLAGER
VILLAGER
```

oluşturulabilir.

Role listesi shuffle edilmeli.

Örneğin oyuncular:

```text
Player 1 -> MEDIUM
Player 2 -> VILLAGER
Player 3 -> VAMPIRE
Player 4 -> DOCTOR
Player 5 -> VILLAGER
Player 6 -> JESTER
Player 7 -> VAMPIRE
Player 8 -> VILLAGER
```

şeklinde random atanmalı.

---

# 2.2 Zorunlu Roller

Her oyunda:

```text
VAMPIRE >= 1
VILLAGER >= 1
```

olmalı.

Host tarafından seçilen diğer roller kalan slotlara dağıtılmalı.

Eğer seçilen özel roller oyuncu sayısından fazla ise server geçerli bir role pool oluşturmalı.

Client'a güvenilmemeli.

---

# 2.3 Randomization

Python backend kullanılıyorsa server-side secure random kullan.

Örneğin:

```python
import secrets

rng = secrets.SystemRandom()
rng.shuffle(role_pool)
```

Role assignment yalnızca backend'de yapılmalı.

Aynı oyuncunun client tarafından rolünü değiştirmesi mümkün olmamalı.

---

# 2.4 Role Assignment Event

Oyun başladığında her oyuncuya sadece kendi rolü gönderilmeli.

```json
{
  "event": "ROLE_ASSIGNED",
  "data": {
    "role": "VAMPIRE"
  }
}
```

Client:

```text
ROLE_ASSIGNED
      ↓
Role Reveal Screen
      ↓
Player sees own role
```

Diğer oyuncuların rolleri client state'e yazılmamalı.

---

# 3. CHAT BİLDİRİMİ

Yeni chat mesajı geldiğinde oyuncu chat ekranında değilse bildirim göster.

Örneğin:

```text
┌──────────────────────────────┐
│ Ahmet                        │
│ Bence Furkan vampir.         │
└──────────────────────────────┘
```

Bu notification 2-4 saniye görünmeli.

---

# 3.1 Unread Message Count

Chat iconunda unread badge oluştur.

Örneğin:

```text
💬 3
```

Yeni mesaj:

```text
unreadCount++
```

Chat açıldığında:

```text
unreadCount = 0
```

---

# 3.2 Chat Açıkken

Oyuncu chat ekranındaysa:

```text
Yeni mesaj
     ↓
Chat listesine ekle
     ↓
Notification gösterme
```

---

# 3.3 Chat Kapalıyken

Oyuncu başka bir ekrandaysa:

```text
Yeni mesaj
     ↓
Chat state
     ↓
Unread count + 1
     ↓
In-app notification
```

göster.

Notification'a dokunulduğunda chat ekranı açılmalı.

---

# 3.4 Birden Fazla Mesaj

Mesaj spam'i oluşturma.

Örneğin 5 mesaj kısa sürede gelirse:

```text
5 yeni mesaj
```

gibi tek notification gösterilebilir.

Chat badge:

```text
💬 5
```

olmalı.

---

# 3.5 Özel Chat

Vampir chat'i gibi özel chat kanalları için de notification sistemi çalışmalı.

Örneğin:

```text
VAMPİR SOHBETİ

Yeni mesaj
```

sadece vampirlere gönderilmeli.

Normal köylüler bu event'i almamalı.

---

# 4. FLUTTER COMPONENTLER

Aşağıdaki reusable componentleri oluştur veya mevcut componentleri genişlet:

```text
NightResolutionScreen
NightActionCard
ActionResultCard
RoleRevealCard
ChatNotification
UnreadChatBadge
GamePhaseHeader
```

---

# 5. NIGHT RESOLUTION TASARIMI

Night Resolution ekranı oyunun önemli ekranlarından biri olmalı.

Animasyon:

```text
Fade In
↓
Action cards sequentially appear
↓
Result appears
↓
Continue button
```

Örneğin:

```text
GECE 2 SONUCU

🧛 Vampirler saldırdı...

🩺 Birisi korundu...

☠ Kimse ölmedi.

[ GÜNDÜZE GEÇ ]
```

Bu ekran oyun atmosferine uygun şekilde dark fantasy tasarımını korumalı.

---

# 6. TESTLER

## Random Role Tests

Test et:

```text
Vampire mevcut
Villager mevcut
Roles shuffled
Client role değiştiremiyor
Her player yalnızca kendi rolünü görüyor
```

## Night Action Tests

Test et:

```text
Vampire target kaydediliyor
Doctor target kaydediliyor
Medium target kaydediliyor
Night sonunda actions resolve ediliyor
Doctor koruması çalışıyor
Vampire saldırısı çalışıyor
Ölüm sonucu doğru hesaplanıyor
Night Resolution oluşturuluyor
```

## Night Resolution Tests

Test et:

```text
Night Resolution event gönderiliyor
Normal player gizli aksiyonları görmüyor
İlgili role kendi aksiyon sonucu gösteriliyor
Detaylı sonuç ayarı çalışıyor
Day phase Resolution sonrasında başlıyor
```

## Chat Tests

Test et:

```text
Chat açıkken notification yok
Chat kapalıyken notification var
Unread count artıyor
Chat açıldığında unread count sıfırlanıyor
Birden fazla mesaj spam oluşturmuyor
Vampire chat notification sadece vampirlere gidiyor
```

---

# 7. IMPLEMENTATION SIRASI

Şu sırayı takip et:

```text
1. Mevcut projeyi analiz et

2. Role assignment sistemini random yap

3. NightAction modelini oluştur

4. Gece aksiyonlarını server'da kaydet

5. Night Resolution mekanizmasını oluştur

6. NIGHT_RESOLUTION WebSocket eventini oluştur

7. Flutter Night Resolution ekranını oluştur

8. Player-specific action result sistemini oluştur

9. Chat unread state oluştur

10. Chat notification oluştur

11. Özel chat notificationlarını ekle

12. Unit tests

13. Integration tests

14. Baştan sona multiplayer test
```

---

# SON KURAL

Mevcut projeyi baştan yazma.

Önce mevcut:

```text
Flutter architecture
Backend
WebSocket
GameState
Role System
Night/Day System
Chat
Voting
```

yapılarını analiz et.

Sonra sadece gerekli değişiklikleri yap.

Özellikle **Night Resolution** sistemini server-authoritative tasarla.

Server gece boyunca yapılan tüm aksiyonları bilmeli ve sonuçlarını hesaplamalıdır.

Ancak oyunculara gönderilen bilgiler rol ve oyun ayarlarına göre filtrelenmelidir.

Amaç:

**Oyuncunun her gece sonunda "o gece ne oldu?" hissini yaşayacağı, aksiyonların görsel olarak sıralandığı ve ardından gündüz fazına geçildiği kaliteli bir multiplayer oyun deneyimi oluşturmaktır.**