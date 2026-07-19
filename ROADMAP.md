# LimesTV — Roadmap CarPlay

## Contesto entitlement (2026)
- La UI CarPlay non usa UIKit/SwiftUI: si costruisce con **template** renderizzati dal
  sistema (lista, griglia, now-playing). È un front-end separato dall'app SwiftUI.
- L'audio in auto funziona già oggi tramite il normale instradamento audio del telefono
  (Bluetooth / uscita CarPlay): **non richiede alcun entitlement**.
- Per mostrare la UI dell'app sullo schermo dell'auto serve un **entitlement CarPlay**.
  - **Video** (`com.apple.developer.carplay-video`): **già richiesto**. È una app CarPlay a
    tutti gli effetti → consente i template di navigazione (griglia/lista) + Now Playing.
    Video solo a veicolo **fermo**, solo su **auto compatibili** (iOS 26+), flusso via AirPlay.
  - **Audio** (`com.apple.developer.carplay-audio`): **opzionale**, non necessario per la
    griglia. Utile solo se in futuro vogliamo l'audio anche a veicolo in movimento.

## Fase 0 — Prerequisiti
1. Attendere/confermare la concessione dell'entitlement **video** e inserirlo nel
   provisioning profile + file `.entitlements`.
2. Abilitare **Background Modes → Audio** in Info.plist (riproduzione continua).
3. Test tramite **CarPlay Simulator** (Xcode → I/O). Il video-in-car richiede hardware.

## Fase 1 — Griglia canali su CarPlay + zap al tap
### 1A. Refactor abilitante: riproduzione condivisa
Oggi la riproduzione vive in `PlayerViewModel`, legato alla view SwiftUI. CarPlay gira in
una **scene separata**, quindi serve una sorgente di verità a livello app:
- Estrarre un **`PlaybackController`** app-level (owner di `AVPlayer`, lista canali, indice
  corrente, `play/next/previous`), usato sia dal player del telefono sia da CarPlay.
- Store canali condiviso (riusa `PlaylistService`), indipendente da `ContentView`.
- Integrare **MPNowPlayingInfoCenter** + **MPRemoteCommandCenter** (metadati e comandi).
- `PlayerViewModel` delega al `PlaybackController` (mantiene l'MVVM).

### 1B. Scene CarPlay
- Info.plist: seconda scene `CPTemplateApplicationSceneSessionRoleApplication`.
- `CarPlaySceneDelegate: CPTemplateApplicationSceneDelegate` (`didConnect/didDisconnect`,
  conserva il `CPInterfaceController`).

### 1C. UI a template
- Root template con i canali (lista con sezioni per `group`, oppure griglia).
- Tap su canale → `PlaybackController.play(channel)` + push di `CPNowPlayingTemplate`.
- `CarPlayCoordinator` costruisce i template dallo store (logica fuori dal delegate).

### 1D. Sync
- Cambio canale da CarPlay riflesso sul telefono e viceversa (stesso `PlaybackController`).

**Esito:** in auto lista/griglia canali, tap = cambio canale, audio in auto; video sul telefono.

## Fase 2 — Video su CarPlay (a veicolo fermo)
Quando l'entitlement video è attivo nel profilo:
1. Aggiungere l'entitlement video al profilo + `.entitlements`.
2. Garantire il supporto **AirPlay video** sull'`AVPlayer` (requisito Apple).
3. Integrare la categoria video: il sistema instrada il video sul display auto **solo da
   fermo** (lock-out gestito dal sistema); gestire transizione parked ↔ driving.
4. Estendere Now Playing / template per l'esperienza video.
5. Test: serve auto compatibile (il simulatore potrebbe non coprire il video-in-car).

## Sequenza consigliata
1. Fase 1A (refactor `PlaybackController`) — fondamento, indipendente da Apple.
2. Fase 1B–D (scene + griglia) — testabile in CarPlay Simulator.
3. Fase 2 quando l'entitlement video è attivo e con hardware compatibile.
