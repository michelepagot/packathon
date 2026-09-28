# Packathon

### Packaging e Distribuzione Software su Linux

<p class="text-muted" style="margin-top: 30px;">Linux Day Trieste 2026</p>

Note:
Lasciare ocio in esecuzione live su un secondo schermo o finestra divisa.
Gag di apertura:
"Gli organizzatori mi hanno invitato qui oggi per parlarvi di packaging e release engineering. Ma siamo onesti: io in realta' sono qui per mostrarvi la mia applicazione vibecodata in 15 minuti che vi cambiera' per sempre la vita."
Muovere il mouse, mostrare l'occhio che traccia il cursore, premere V per mostrare la versione (Ocio v0.1.0).
"Ora che l'avete vista, so che la volete tutti. Ma non ho un server o una pipeline di distribuzione. Quindi ho deciso di distribuirla alla vecchia maniera."
Estrarre il floppy disk fisico da 3.5" dalla borsa:
"Se a fine talk mi lasciate il vostro indirizzo postale e un francobollo, ve la spedisco per posta."
Il ritorno alla realta':
Cosa succede se carico questo binario grezzo compilato su un server web e dico a 50 sconosciuti di scaricarlo ed eseguirlo?
Fallisce immediatamente su macchine diverse: glibc disallineata, collegamenti dinamici DT_NEEDED mancanti (libGL.so, libX11.so), socket del display server assente o problemi di permessi.
La cavia: perche' questa app:
Sorgente volutamente banale: un solo main.c, ~280 righe di C99 pulito, zero logica di business: nulla compete con il packaging per l'attenzione.
Footprint di runtime massimamente realistico: richiede accelerazione hardware OpenGL via DRI, un display server attivo (X11 / Wayland) e IPC su memoria condivisa (MIT-SHM).
"Sorgente massimamente semplice, footprint di runtime massimamente realistico."

--

## Slides
<!-- .slide: class="text-center" -->

<div class="center-card">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&amp;data=https://michelepagot.github.io/packathon/" alt="Slide QR Code" style="border-radius: 12px; border: 3px solid rgba(255,255,255,0.4);" />
  <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
</div>

Note:
Pausa per consentire al pubblico di inquadrare il QR code e seguire live su smartphone o portatili.

--

## Speaker

* **Michele Pagot**
* **SUSE**: Quality Engineering (QE)
* GitHub: [`@michelepagot`](https://github.com/michelepagot) · [`@mpagot`](https://github.com/mpagot)

Note:
Breve presentazione del relatore.

--

## Disclaimer

* Non sono un package maintainer di professione.
* Lavoro in QE...

Note:
"Non sono un package maintainer di professione. Lavoro all'estremita' della pipeline: test, validazione e analisi degli output di rilascio su sistemi completi. Questo talk nasce come indagine ingegneristica per capire a fondo la catena che genera gli artefatti a monte prima che arrivino ai banchi di test."

--

## Agenda

<div class="grid-2">
<div>

1. **Censimento**
2. **Prospettive**
3. **Dipendenze**
4. **Formati**
5. **Delega**: RPM &amp; DEB *(Demo)*

</div>
<div>

6. **AppImage**, **Flatpak**, **Permessi**
7. **Rilascio** &amp; **Aggiornamenti**
8. **Firme** &amp; **SBOM**
9. **Sintesi**, **Metriche**, **Q&amp;A**

</div>
</div>

Note:
Panoramica sintetica della progressione del talk.

---

## Censimento

1. Chi usa Linux quotidianamente? <!-- .element: class="fragment" -->
2. Chi installa software esclusivamente tramite repository ufficiali? <!-- .element: class="fragment" --> <br><small class="text-muted">(APT, Zypper, DNF, Pacman, AUR... Emerge, Slackpkg, urpmi)</small>
3. Chi usa formati universali: Flatpak, AppImage o Snap? <!-- .element: class="fragment" -->
4. <!-- .element: class="fragment" --> `curl | sh`
5. Chi compila regolarmente da sorgenti? <!-- .element: class="fragment" --> <br><small class="text-muted">(<code>git clone &amp;&amp; cmake &amp;&amp; make &amp;&amp; sudo make install</code>)</small>

Note:
Scandire le 5 domande guardando la sala:
1. 100% mani alzate.
2. Repo ufficiali: cittadini modello con fiducia cieca nei maintainer.
3. Flatpak/AppImage: chi cerca novita' upstream o si e' arreso alla dependency hell.
4. curl | sh: pragmatismo notturno vs sicurezza della supply chain azzerata.
5. Compilazione: puristi di /usr/local.
Takeaway:
"Guardatevi intorno: in questa sala non esiste un solo modo in cui il software viene ricevuto su Linux. Ognuno opera con un modello di fiducia diverso, aspettative di aggiornamento diverse e compromessi operativi diversi."

--

## Prospettive

* <!-- .element: class="fragment" --> Utilizzatore
* <!-- .element: class="fragment" --> Sviluppatore
* <!-- .element: class="fragment" --> Maintainer

Note:
Presentare le tre prospettive una alla volta:

1. L'Utilizzatore (punto di partenza comune: vuole semplicemente l'applicazione):
- Ma le necessita' interne sono divergenti: c'e' chi vuole una versione rocciosa e stabile per lavorare senza sorprese, e chi pretende l'ultimissima release con le novita' del giorno zero.
- Vogliamo che si installi in meno passaggi possibile e vogliamo poterla aggiornare senza attriti.
- C'e' chi guarda la reattivita' e vuole che parta istantaneamente, chi ha poco disco o RAM e non tollera sprechi, e chi se ne frega dello spazio purche' non debba configurare nulla.
- E poi c'e' la variabilita' fisica: ognuno ha un hardware e una scheda video diversa, e quando cambiamo PC o passiamo a un'altra distro pretendiamo di ritrovare la stessa identica applicazione funzionante.

2. Lo Sviluppatore (focalizzato su chi distribuisce pubblicamente, non su commessa singola):
- L'obiettivo e' raggiungere la platea piu' ampia possibile.
- Conosce alla perfezione la propria applicazione, la sua logica e le sue dipendenze dirette.
- Ma non conosce i dettagli e le particolarita' di venti distribuzioni diverse, e non possiede il laboratorio hardware necessario per testare ogni permutazione di kernel, driver e librerie.
- Vive una totale asimmetria di potere: controlla al 100% il proprio codice sorgente, ma ha zero potere sul sistema operativo su cui il programma dovra' girare. Vuole solo una cosa: che cio' che ha compilato e testato funzioni senza sorprese sul computer di chi lo scarica.

3. Il Maintainer / Distro Owner:
- Conosce la specifica applicazione meno bene del suo creatore, e conosce il build system dell'app molto meno dello sviluppatore.
- Conosce pero' benissimo il sistema operativo nel suo insieme e tutti gli altri 30.000 pacchetti distribuiti.
- Il suo interesse primario e' che la roba distribuita parta, funzioni e non corrompa il sistema: incompatibilita' ABI, collisioni di file in /usr e falle di sicurezza nelle librerie condivise (se c'e' una CVE su OpenSSL, vuole patcharla una volta per tutte le applicazioni).
- Anche qui ci sono ideali ed esigenze diverse: chi vuole avere piu' applicazioni possibili nei repo a costo di sforzi enormi (catalogo sterminato), chi ne vuole poche ma rigidamente testate e fresche; chi persegue la rolling release continua (Tumbleweed, Arch) e chi la stabilita' decennale (SLES, Debian, RHEL).

Pausa interattiva con la sala:
"Prima di addentrarci nel COME, fermiamoci a riflettere sul PERCHE'. Guardate questo quadro: vi riconoscete in queste tensioni? C'e' qualche vincolo o necessita' fondamentale che uno di questi tre attori vive ogni giorno e che qui non abbiamo nominato?"

Raccordo verso il resto del talk:
"Nessuno ha ragione o torto: sono investimenti legittimi di tempo, energie e risorse su aspetti diversi. I formati di packaging che esploriamo oggi non nascono per rivalita', ma sono risposte ingegneristiche diverse per arbitrare questo trilemma. Ora vediamo il COME: cosa succede quando proviamo a distribuire il nostro binario."

--

## Dipendenze

> *"Sul mio computer va"*

```text
/ocio: error while loading shared libraries: libOpenGL.so.0:
cannot open shared object file: No such file or directory
```
<!-- .element: class="fragment" -->

Note:
Chiedere al pubblico il codice di uscita: 127.

Comando di test in container minimale:
$ podman run --rm -v ./build/bin/ocio:/ocio:ro,Z registry.opensuse.org/opensuse/tumbleweed:latest /ocio

Aggancio scenico:
"Abbiamo compilato, messo il binario su una chiavetta o scaricato da GitHub, e lo lanciamo su una macchina pulita. Risultato immediato: errore a runtime.
Chi ha interrotto l'esecuzione? Il programma e' crashato? E' stato il kernel?
Guardiamo cosa succede realmente sotto il cofano all'avvio."

--

## Avvio

`$ ocio`

1. **Shell**: ricerca in `$PATH` &rarr; `/usr/bin/ocio` <small>(`command -v ocio`)</small>
2. **Kernel**: `execve()` &rarr; `PT_INTERP` &rarr; `ld.so`
3. **ld.so**: `DT_NEEDED` &rarr; `/lib64/libOpenGL.so.0` trovato
4. `main()`

Note:
La sequenza esatta di avvio di un ELF su Linux:
1. La shell trova il file tramite $PATH.
2. Il kernel chiama execve(), mappa l'ELF e passa il controllo all'interprete (ld.so). Il kernel ha fatto il suo lavoro senza errori!
3. Il dynamic linker (in userspace) scansiona le voci DT_NEEDED.
Ed e' qui che si consuma la tragedia: non trovando libOpenGL.so.0, ld.so stampa l'errore e invoca exit_group(127).
4. main() non viene mai raggiunto. Il codice C non ha eseguito una sola istruzione.

Ponte verso la slide successiva:
"Ma come e' possibile? Sul computer di sviluppo compilava senza warning ed eseguiva perfettamente. Come fa un compilatore a produrre un binario che muore prima ancora di entrare in main()?"

--

## Build vs. Runtime

<div class="grid-2">
<div>

### Build-Time
* Consumate **una volta**
* Header &amp; librerie statiche
* Compilatore &amp; tool

</div>
<div>

### Runtime
* Richieste **a ogni avvio**
* `.so` dinamiche &amp; `glibc`
* Display &amp; nodi GPU

</div>
</div>

<p class="fragment text-info" style="margin-top: 35px;">
<em>In C, un binario dinamico è un contratto incompleto con l'OS host.</em>
</p>

Note:
Compilare con successo non significa avere un'applicazione autosufficiente.
- A build-time servono solo le dichiarazioni (header) e i simboli per generare il formato ELF.
- A runtime servono le implementazioni concrete (.so), il display server e i driver GPU.
In C, un binario collegato dinamicamente e' un contratto incompleto che deve essere onorato dall'ambiente host a runtime.

Ponte verso la slide successiva:
"Se il binario e' un contratto incompleto... come facciamo a verificare esattamente cosa richiede questo binario e cosa manca sulla macchina host?"

--

## Seguendo libOpenGL.so.0

```text
$ readelf -d ocio | grep NEEDED
 (NEEDED)  Shared library: [libm.so.6]
 (NEEDED)  Shared library: [libOpenGL.so.0]
 (NEEDED)  Shared library: [libGLX.so.0]
 (NEEDED)  Shared library: [libc.so.6]
```

```text
$ ldd ./ocio
    linux-vdso.so.1 (0x00007ffe315f6000)
    libm.so.6 => /lib64/libm.so.6 (0x00007f9c8f2b0000)
    libOpenGL.so.0 => not found
    libGLX.so.0 => not found
    libc.so.6 => /lib64/libc.so.6 (0x00007f9c8f0b0000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f9c8f3b0000)
```
<!-- .element: class="fragment" -->

Note:
Come si manifesta questo contratto incompleto?
1. readelf -d legge direttamente l'header ELF del binario: le voci DT_NEEDED elencano cio' che il compilatore ha registrato come dipendenze dinamiche.
2. ldd simula l'interprete dinamico (ld.so) sull'host: per ciascuna voce cerca la libreria nei percorsi di sistema.
Risultato: libOpenGL.so.0 e libGLX.so.0 risultano "not found".

Ponte verso la sezione Formati:
"Il binario richiede queste librerie, ma il sistema dell'utente non le possiede. Come facciamo a distribuirle o a garantire che siano presenti?
E' qui che entra in gioco il packaging: ciascun formato su Linux adotta una strategia radicalmente diversa per colmare questo divario."

---

## Formati

| Target | Meccanismo |
|---|---|
| **Standalone Tarball** | Archivio compresso (`.tar.gz`) con asset e `.desktop` |
| **RPM (`.rpm`)** | Payload CPIO per Fedora/openSUSE/RHEL |
| **Debian (`.deb`)** | Archivio `ar` standard via CPack |
| **AppImage** | File unico con SquashFS montato via FUSE |
| **Flatpak** | Sandbox Bubblewrap su runtime Freedesktop |

Note:
Lo spettro dei formati esplorati: dal semplice tarball non gestito ai pacchetti di sistema, bundle auto-montanti e sandbox desktop.
Regola di conteggio: non citare mai il numero totale dei formati a voce (le liste differiscono intenzionalmente tra le sezioni).
Transizione verso la Rotta 1: approfondiremo i 4 grandi formati desktop (RPM, DEB, AppImage, Flatpak), partendo dalla delega alla distribuzione.

---

## RPM: Standard Nativo

* *Marc Ewing &amp; Erik Troan* (Red Hat, 1997)
* Archivio con metadati di dipendenza
* Standard enterprise e distro (LSB)

<p class="fragment text-info" style="margin-top: 35px;">
<strong>Superpotere:</strong> Delega la risoluzione delle dipendenze al graph solver dell'OS.
</p>

Note:
Introduciamo RPM:
- Origine: Creato nel 1997 da Marc Ewing ed Erik Troan (Red Hat).
- Natura: Un archivio con metadati che trasporta file e dichiara dipendenze formali.
- Diffusione: Lo standard di riferimento per openSUSE, SLE, Fedora e RHEL (specifica LSB).
- CLI quotidiana:
  * Ispezione: rpm -qlp (file) e rpm -qp --requires (dipendenze)
  * Installazione con risolutore: zypper in oppure dnf in
  * Verifica integrita': rpm -V (rileva file alterati rispetto ai digest del db)
- Superpotere: Delega al solver SAT della distribuzione.
Ora andiamo a vedere cosa c'e' fisicamente dentro il file .rpm sul disco.

--

## Dentro un RPM: Struttura

```text
$ file ocio-0.1.0-1.x86_64.rpm
ocio-0.1.0-1.x86_64.rpm: RPM v3.0 bin i386/x86_64
```
<!-- .element: class="fragment" -->

| Lead | Signature | Header | Payload |
|:---:|:---:|:---:|:---:|
| `magic` | `digests, GPG` | `name, deps, files` | `cpio (zstd)` |
<!-- .element: class="fragment" -->

```text
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | file -
/dev/stdin: ASCII cpio archive (SVR4 with no CRC)
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | cpio -idmv
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```
<!-- .element: class="fragment" -->

Note:
file identifica il formato dai byte magici (ed ab ee db): "RPM v3.0" e' il formato lead legacy, ancora scritto da rpm moderno per compatibilita'.
Anatomia del file:
- Lead: blocco fisso legacy, oggi quasi solo un magic number.
- Signature: digest di header e payload, piu' la firma GPG quando presente (il nostro non ne ha).
- Header: tutti i metadati che interroghiamo con rpm -q (nome, versione, Requires, Provides, elenco file con digest).
- Payload: i file effettivi, in un archivio cpio compresso con zstd (rpm -qp --qf '%{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR}' stampa "cpio zstd").
Cos'e' cpio:
- Formato di archivio Unix degli anni '70 ("copy in / copy out"), stessa idea di tar: una sequenza lineare di record (header + dati file).
- Nessuna compressione e nessun indice interno; la compressione viene applicata sopra (qui zstd).
- Variante SVR4 "newc": header ASCII, magic "070701". Il kernel Linux usa lo stesso formato per l'initramfs.
Come estrarlo (fragment):
- rpm2cpio rimuove lead, signature e header, decomprime il payload e scrive il flusso cpio su stdout.
- cpio -i estrae, -d crea le directory, -m preserva i timestamp di modifica, -v elenca i file.
- I percorsi sono relativi (./usr/...): tutto finisce nella directory corrente, il sistema non viene toccato.
- Scorciatoia: bsdtar -tf / -xf legge direttamente i file RPM.
- L'eseguibile estratto ./usr/bin/ocio e' identico byte per byte al binario compilato.
Messaggio chiave: estrarre significa solo copiare file. Nessun controllo di dipendenze, nessun record nel database, nessuno script. L'installazione e' cio' che rpm aggiunge sopra: tenetelo a mente per le prossime slide.

--

## Dentro un RPM: Payload

```text
$ rpm -qlp ocio-0.1.0-1.x86_64.rpm
/usr/bin/ocio
/usr/share/applications/ocio.desktop
/usr/share/icons/hicolor/256x256/apps/ocio.png
/usr/share/icons/hicolor/scalable/apps/ocio.svg
/usr/share/metainfo/org.packathon.ocio.metainfo.xml
```

Note:
rpm puo' interrogare il file senza installarlo (-p = file di pacchetto).
Dettaglio del payload (directory omesse dall'elenco):
- /usr/bin/ocio: il binario, posizionato in una directory gia' presente nel $PATH di sistema.
- .desktop + icone: desktop entry e icone per consentire al desktop environment di mostrarlo nei menu.
- metainfo XML: metadati AppStream affinche' i software center grafici (GNOME Software, Discover) presentino descrizioni, categorie e screenshot.

--

## Dentro un RPM: Metadati

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm
libOpenGL.so.0()(64bit)
libGLX.so.0()(64bit)
libc.so.6(GLIBC_2.34)(64bit)
libm.so.6(GLIBC_2.43)(64bit)
...
```

```text
$ rpm -qp --provides ocio-0.1.0-1.x86_64.rpm
ocio = 0.1.0-1
application(ocio.desktop)
```
<!-- .element: class="fragment" -->

Note:
Ispezione dell'header:
- Guardate i Requires: libOpenGL.so.0, libGLX.so.0. Questo e' esattamente l'elenco DT_NEEDED del crash iniziale.
- Nessuno ha scritto queste righe a mano: il dependency generator di rpmbuild scansiona il binario ELF (DT_NEEDED + versioni simboli glibc) e compila l'header in automatico.
- Provides: cosa offre questo pacchetto al sistema (nome pacchetto, versione e capacita' desktop).
- Parcheggiamo GLIBC_2.43: notate questa baseline di simboli; ci torneremo analizzando i trade-off della delega.

--

## Demo Live: RPM

Installazione RPM in container openSUSE Tumbleweed *vanilla*:

```bash
$ podman run --rm -v "$PWD/dist/ocio-0.1.0-1.x86_64.rpm:/ocio.rpm:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    sh -c "zypper --non-interactive in --allow-unsigned-rpm /ocio.rpm && ocio --version"
```

<p class="text-warn" style="margin-top: 30px;">* <code>--allow-unsigned-rpm</code></p>

Note:
Eseguire la demo live o mostrare il comando a terminale.
Cosa fa zypper, in ordine (visibile nel suo output):
- Resolve: calcola i 36 pacchetti.
- Retrieve: li scarica (ocio stesso dalla cache dei file RPM locali).
- Verify: controlla le firme. Qui non puo': il nostro pacchetto non e' firmato.
- Check for file conflicts: nessun pacchetto puo' possedere lo stesso percorso.
- Install: scompatta i file in /usr, registra ogni file nel database RPM.
Dettaglio critico dell'asterisco: --allow-unsigned-rpm. rpm -qi ocio mostra "Signature: (none)" e "Build Host: e246f0b7ceaf" (un ID container casuale): nulla prova chi abbia costruito questo pacchetto. Questo non include scriptlet (rpm -qp --scripts e' vuoto), ma il prossimo RPM non firmato potrebbe averne, e gli scriptlet girano come root. Anticipare la sezione Firme.

--

## Dopo l'Installazione: Risolto

```text
$ ldd /usr/bin/ocio
  libm.so.6 => /lib64/libm.so.6
  libOpenGL.so.0 => /lib64/libOpenGL.so.0
  libGLX.so.0 => /lib64/libGLX.so.0
  libc.so.6 => /lib64/libc.so.6
  libGLdispatch.so.0 => /lib64/libGLdispatch.so.0
  libX11.so.6 => /lib64/libX11.so.6
  libxcb.so.1 => /lib64/libxcb.so.1
  ...
```

<p class="fragment text-info" style="margin-top: 25px;">
<strong>486 KB</strong> di pacchetto &rarr; <strong>36</strong> pacchetti &rarr; <strong>52.6 MiB</strong> di download
</p>

Note:
Confronto diretto con il crash iniziale:
- Ogni libreria prima mancante (libOpenGL.so.0, libGLX.so.0) e' ora risolta con un percorso assoluto in /lib64.
- Notate la risoluzione transitiva: il loader ha risolto anche le dipendenze secondarie tirate dentro da libglvnd (libGLdispatch, libX11, libxcb).
- Il costo della delega: per installare il nostro pacchetto da 486 KB, il SAT solver (libsolv) ha selezionato 36 pacchetti dal repository per un totale di 52.6 MiB di download.
- Il contratto userspace e' ora completamente soddisfatto dalla distribuzione.

--

## Dopo l'Installazione: Registrato e Protetto

```text
$ rpm -qf /usr/lib64/libOpenGL.so.0
libglvnd-1.7.0-2.4.x86_64
```

```text
$ rpm -V ocio && echo clean
clean
```
<!-- .element: class="fragment" -->

```text
$ rpm -e --test libglvnd
error: Failed dependencies:
  libOpenGL.so.0()(64bit) is needed by (installed) ocio-0.1.0-1.x86_64
```
<!-- .element: class="fragment" -->

Note:
Installare significa copiare file e mantenere un database autorevole:
- Proprieta' (rpm -qf): ogni singolo file sul filesystem ha un pacchetto proprietario certo e tracciabile.
- Verifica integrita' (rpm -V): verifica i file rispetto ai digest sha256 memorizzati. Se un file viene manomesso, rpm -V lo segnala all'istante.
- Protezione dipendenze (rpm -e --test): il sistema impedisce la rimozione accidentale di librerie necessarie ad altri pacchetti installati.

--

## DEB: Standard Debian

* *Ian Murdock* (Debian, 1993)
* Rigide policy e conformità FHS
* Standard Debian, Ubuntu e Mint

<p class="fragment text-info" style="margin-top: 35px;">
<strong>Superpotere:</strong> Mappatura esatta dei simboli via <code>dpkg-shlibdeps</code> e scriptlet di controllo.
</p>

Note:
Introduciamo DEB:
- Origine: Creato nel 1993 da Ian Murdock per la release iniziale di Debian.
- Natura: Formato vincolato da rigide policy di packaging della distribuzione e conformita' FHS.
- Diffusione: Lo standard di riferimento per Debian, Ubuntu, Linux Mint e derivate.
- CLI quotidiana:
  * Ispezione: dpkg-deb -c (file) e dpkg-deb -I (metadati di controllo)
  * Installazione con risolutore: apt install ./file.deb
  * Verifica integrita': debsums (verifica integrita' file rispetto ai checksum md5)
- Superpotere: Mappatura esatta dei simboli di libreria e scriptlet di controllo.
Ora vediamo cosa c'e' fisicamente dentro un file .deb sul disco.

--

## Dentro un DEB: Archivio Unix `ar`

```text
$ file ocio_0.1.0_amd64.deb
ocio_0.1.0_amd64.deb: Debian binary package (format 2.0)
```

```text
$ ar -t ocio_0.1.0_amd64.deb
debian-binary
control.tar.xz
data.tar.xz
```
<!-- .element: class="fragment" -->

```text
$ dpkg-deb -I ocio_0.1.0_amd64.deb | grep Depends
 Depends: libc6 (>= 2.17), libgl1, libx11-6
```
<!-- .element: class="fragment" -->

Note:
Anatomia di un file .deb:
- Non usa alcun formato contenitore proprietario: e' un archivio standard Unix ar (lo stesso formato usato per le librerie statiche .a).
- Contiene esattamente tre membri:
  1. debian-binary: stringa di testo con la versione del formato ("2.0\n").
  2. control.tar: archivio compresso con i metadati del pacchetto (file control, md5sums, scriptlet postinst/prerm).
  3. data.tar: archivio compresso contenente i file del payload effettivo da scompattare sul filesystem.
- dpkg-deb -I: ispeziona i metadati di controllo. Depends: libc6, libgl1, libx11-6 e' generato automaticamente da dpkg-shlibdeps.

--

## Dialetti

| Dimensione | Ecosistema RPM | Ecosistema DEB |
|---|---|---|
| **Contenitore** | CPIO (`zstd`) | Archivio `ar` standard |
| **Tool base** | `rpm` | `dpkg` |
| **Package manager** | `zypper` / `dnf` | `apt` |
| **Risolutore deps** | `find-requires` | `dpkg-shlibdeps` |
| **Ispezione file** | `rpm -qlp` | `dpkg-deb -c` |
| **Ispezione metadati** | `rpm -qp --requires` | `dpkg-deb -I` |
| **Verifica integrità** | `rpm -V` | `debsums` |
<!-- .element: style="font-size: 0.76em;" -->

Note:
Due dialetti, stesso principio ingegneristico:
- Contenitori: RPM usa un payload CPIO compresso (zstd o gzip); DEB usa un classico archivio Unix ar contenente control.tar (metadati) e data.tar (payload).
- Generazione dipendenze: find-requires scansiona le voci ELF DT_NEEDED; dpkg-shlibdeps mappa i simboli tramite i file symbols delle librerie.
- Ispezione: rpm -qlp FILE.rpm vs dpkg-deb -c FILE.deb per i file; rpm -qp --requires vs dpkg-deb -I per i metadati.
- Integrita': rpm -V PACKAGE controlla i digest salvati nel database RPM; debsums PACKAGE verifica i file rispetto ai digest md5sums.
- Risoluzione: Entrambi delegano a un risolutore ad alto livello (zypper/dnf con libsolv, apt con il suo motore di scoring).

--

## Delega

* **Filosofia**: Il pacchetto trasporta solo il payload; dipendenze delegate alla distribuzione.

<div class="grid-2 fragment" style="margin-top: 25px;">
<div class="box-success">

#### Vantaggi

* Payload minimo: **486 KB** (52.6 MiB delegati)
* Librerie condivise: patchate una volta per tutte le app
* Proprietà e verifica: `rpm -qf`, `rpm -V`

</div>
<div class="box-danger">

#### Limiti

* Accoppiamento ABI: `libm.so.6(GLIBC_2.43)`
* Rigide policy di packaging (FHS, scriptlet)
* Una build per ciascuna distribuzione target

</div>
</div>

Note:
Riepilogo: ogni punto si riferisce direttamente a cio' che la sala ha appena visto:
- 486 KB vs 52.6 MiB: la distribuzione si fa carico del grafo delle dipendenze a runtime.
- Librerie condivise: libglvnd e' condivisa tra tutte le app GL; una vulnerabilita' viene corretta una volta sola per l'intero sistema.
- GLIBC_2.43 nei Requires: questo pacchetto si installa solo dove esiste glibc >= 2.43. Compilato su Tumbleweed, non parte su una LTS meno recente.
- Il prezzo della delega e' lo stretto accoppiamento con l'host.

---

## AppImage: Singolo File Portabile

<div class="grid-2">
<div>

### Cos'è
* Un'app = un singolo file eseguibile
* *Simon Peter* (2004 *klik*, 2011)
* Zero installazione, niente root

</div>
<div>

### CLI Quotidiana
* **Esegui**: `chmod +x ./file.AppImage && ./file.AppImage`
* **Estrai**: `./file.AppImage --appimage-extract`
* **Fallback**: Funziona senza FUSE via root estratto

</div>
</div>

<p class="fragment text-info" style="margin-top: 30px;">
<strong>Superpotere:</strong> Portabilità istantanea tramite mount FUSE in userspace.
<br><span class="text-warn">Il Limite:</span> Include l'app, non la glibc ("compila sulla distro più vecchia").
</p>

Note:
Introduciamo AppImage con le 4 lenti:
1. Cos'e': Creato da Simon Peter (probono) nel 2004 come klik, rinominato nel 2011 in AppImage. Idea di fondo: un'applicazione deve essere un unico file cliccabile.
2. Superpotere: Portabilita' istantanea. Non richiede permessi di root, non sporca il sistema e viene montato in userspace tramite FUSE.
3. Flusso comune: Scarica, dai i permessi di esecuzione ed esegui. Se FUSE non e' disponibile (ad esempio in container), --appimage-extract offre un fallback immediato.
4. Il paradosso glibc: AppImage include le librerie dell'applicazione, ma si appoggia a glibc e kernel dell'host. Compilato su una distro rolling, i simboli GLIBC impediscono l'avvio su LTS piu' datate. Regola d'oro: compila sulla distro piu' vecchia che intendi supportare.

--

## Dentro un AppImage: Stub e SquashFS

* **Stub runtime ELF**: piccolo eseguibile posto in testa al file
* **Filesystem SquashFS**: payload compresso accodato direttamente allo stub
* **Mount ed esecuzione**: FUSE monta in `/tmp/.mount_XXXXXX` ed esegue `AppRun`

```text
$ ./ocio-x86_64.AppImage --appimage-extract
$ ls -1 squashfs-root
AppRun
ocio
ocio.desktop
ocio.png
```
<!-- .element: class="fragment" -->

Note:
Meccanica interna di AppImage:
- Un file AppImage e' un binario ELF seguito immediatamente da un filesystem SquashFS compresso.
- All'avvio, lo stub ELF intercetta l'esecuzione, monta il filesystem interno in una directory temporanea in /tmp tramite FUSE ed esegue lo script AppRun all'interno del mount.
- AppRun imposta LD_LIBRARY_PATH e lancia l'applicazione.
- Alla chiusura dell'app, il mount FUSE viene smontato e rimosso.
- L'opzione --appimage-extract dimostra come all'interno vi sia una root di filesystem completa e autosufficiente.

---

## Flatpak: Runtime Desktop in Sandbox

<div class="grid-2">
<div>

### Cos'è
* Standard desktop universale in sandbox
* *Alexander Larsson* (2015 *xdg-app*, 2016)
* Sostenuto dall'ecosistema Flathub

</div>
<div>

### CLI Quotidiana
* **Esegui**: `flatpak run org.packathon.ocio`
* **Ispeziona**: `flatpak run --command=sh <app>`
* **Modifica**: `flatpak override --user <flags>`

</div>
</div>

<p class="fragment text-info" style="margin-top: 30px;">
<strong>Superpotere:</strong> Totale disaccoppiamento dall'host tramite sandbox Bubblewrap non privilegiate.
<br><span class="text-warn">Il Limite:</span> Zero accesso implicito a display, file o GPU dell'host.
</p>

Note:
Introduciamo Flatpak con le 4 lenti:
1. Cos'e': Creato nel 2015 da Alexander Larsson in Red Hat (inizialmente xdg-app). E' diventato lo standard de-facto per app desktop cross-distro su Flathub.
2. Superpotere: Disaccoppiamento radicale. L'applicazione non vede /usr dell'host, ma un ambiente isolato gestito da Bubblewrap con namespace del kernel e filtri seccomp.
3. Flusso comune: Installa da repository remoto (Flathub), esegui, ispeziona l'ambiente interno con --command=sh e gestisci i permessi con flatpak override.
4. Il limite: Poiche' la sandbox e' sigillata per impostazione predefinita, qualsiasi comunicazione con l'esterno deve essere dichiarata esplicitamente.

--

## Dentro Flatpak: Struttura Filesystem

```text
$ flatpak run --command=sh org.packathon.ocio
[org.packathon.ocio ~]$ ls /
app  bin  dev  etc  lib  lib64  proc  run  sys  usr  var
[org.packathon.ocio ~]$ which ocio
/app/bin/ocio
```

* **`/app`**: Payload dell'applicazione e librerie dedicate (mount in sola lettura)
* **`/usr`**: Runtime condiviso (`org.freedesktop.Platform`), immutabile e versionato
* **Host `/`**: Completamente invisibile; isolamento garantito da **Bubblewrap** (`bwrap`)
<!-- .element: class="fragment" -->

Note:
Struttura del filesystem interno in Flatpak:
- L'opzione --command=sh ci posiziona nell'esatto ambiente visibile all'applicazione.
- Notate i due punti di mount fondamentali:
  1. /app contiene esclusivamente i binari dell'app, i file desktop e le librerie dedicate.
  2. /usr e' montato dal runtime condiviso Freedesktop. Fornisce libc, mesa e lo stack grafico di base, identico su Arch, Debian, openSUSE o Fedora.
- Il filesystem root dell'host non e' minimamente accessibile.

--

## Permessi: Varchi nella Sandbox

Non fidarsi dell'host impone di ridichiarare esplicitamente ogni risorsa:

```yaml
# packaging/flatpak/org.packathon.ocio.yml
finish-args:
  - --socket=x11        # Display server X11
  - --socket=wayland    # Wayland compositor socket
  - --device=dri        # GPU acceleration (/dev/dri)
  - --share=ipc         # Shared memory (MIT-SHM)
```

<p class="fragment text-info" style="margin-top: 25px;">
<strong>Conseguenza:</strong> La complessità si sposta dai simboli di libreria dinamica alla configurazione di socket IPC e portali.
</p>

Note:
Spiegare l'apertura dei varchi (hole-punching):
- Quando ci si disaccoppia dall'host, di base si interrompe ogni interazione. L'applicazione non puo' visualizzare finestre, usare la GPU o riprodurre suoni.
- Le finish-args nel manifest Flatpak aprono varchi mirati:
  - i socket per X11/Wayland consentono di disegnare a schermo.
  - /dev/dri abilita l'accelerazione GPU hardware.
  - --share=ipc abilita il trasferimento rapido dei buffer via memoria condivisa (MIT-SHM).
- Messaggio chiave: La complessita' del packaging non scompare mai, si conserva. Invece di risolvere conflitti di simboli DT_NEEDED, ora configuriamo socket IPC e portali XDG.

---

## Rilascio: Artefatto vs Canale

> *"CPack genera cinque formati in una riga. Ma un file non è un canale di distribuzione."*

<div class="grid-2 fragment" style="margin-top: 25px;">
<div class="box-danger">

#### CPack (Artefatto Locale)
* Compila sull'host non isolato dello sviluppatore
* Inserisce percorsi e toolchain locali nei metadati
* Nessuna provenienza crittografica o fiducia

</div>
<div class="box-success">

#### Build Service (OBS / Koji)
* **Chroot isolati** (accesso di rete disabilitato in build)
* Ricompilazioni automatiche su aggiornamenti di libreria
* Controllo policy automatico (`rpmlint`) e firma con chiavi

</div>
</div>

Note:
La tesi centrale dell'Atto 3:
- Creare un .deb o un .rpm con CPack o alien e' tecnicamente banale, ma genera un artefatto orfano.
- Il problema dell'host "sporco": compilando sulla propria macchina di sviluppo si rischia di contaminare i pacchetti con percorsi locali, patch non tracciate o flag del compilatore specifici.
- La vera distribuzione richiede un'infrastruttura di build fidata (Open Build Service, Koji, Launchpad):
  1. Build ermetiche in chroot puliti senza connessione Internet.
  2. Il grafo delle dipendenze innesca ricompilazioni automatiche quando cambiano le librerie condivise.
  3. Controlli di conformita' (rpmlint, suite di test) e firma GPG automatizzata con chiavi protette.

--

## Aggiornamenti: Canale vs Formato

La capacità di aggiornamento dipende dal **canale**, non dal formato:

* **`.deb` / `.rpm` via repository**: Aggiornamenti automatici dell'OS (`apt upgrade`, `zypper dup`). <!-- .element: class="fragment" -->
* **File installato a mano (`dpkg -i` / `rpm -i`)**: Artefatto orfano; nessuna patch futura. <!-- .element: class="fragment" -->
* **Flatpak via Flathub**: Repository **OSTree**; delta statici a blocchi (aggiornamenti atomici). <!-- .element: class="fragment" -->
* **AppImage**: Statico per impostazione predefinita; richiede `.upd_info` nella sezione ELF per abilitare `zsync`. <!-- .element: class="fragment" -->

<p class="fragment text-danger" style="margin-top: 25px;">
<em>Un eseguibile privo di canale di aggiornamento è un debito di sicurezza perpetuo.</em>
</p>

Note:
Il paradosso del ciclo di vita del software:
- Il formato di pacchetto e' solo una fotografia statica. Il meccanismo di aggiornamento e' una relazione continua nel tempo.
- Quando un utente scarica un .deb o un .rpm dalle release di GitHub e lancia dpkg -i o rpm -i, quel pacchetto e' orfano: nessun repository lo conosce e non ricevera' mai patch automatiche dal sistema.
- Flatpak risolve il problema con OSTree: gli aggiornamenti sono indicizzati per contenuto e scaricati come delta binari atomici (vengono trasferiti solo i blocchi modificati).
- AppImage e' completamente isolato di base. L'aggiornamento richiede l'inserimento di una sezione .upd_info nell'eseguibile ELF che punti a un file di controllo zsync su un server remoto.
- Regola fondamentale di sicurezza: distribuire un binario senza un canale di aggiornamento significa lasciare le vulnerabilita' permanentemente sulle macchine degli utenti.

--

## Firme: Integrità e Provenienza

Perché `--allow-unsigned-rpm` è inaccettabile: nessuna prova di origine e gli scriptlet vengono eseguiti come **root**.

| Ecosistema | Livello di Firma | Validazione a Runtime |
|---|---|---|
| **APT** | Metadati repo (`Release.gpg`) | Verifica obbligatoria pre-unpack |
| **RPM** | Header pacchetto + `repomd.xml` | Verifica GPG su keyring di sistema |
| **Flatpak** | Commit &amp; Summary in OSTree | Verifica crittografica ad ogni pull |
| **AppImage** | Blocco ELF integrato (`--appimage-signature`) | **Nessuna validazione automatica** all'avvio |

<p class="fragment" style="margin-top: 25px;">
<strong>Realtà 2026</strong>: <em>Sigstore / Keyless</em> (OIDC) per le release upstream in CI; i keyring GPG tradizionali restano obbligatori per i package manager di sistema.
</p>

Note:
Le implicazioni di sicurezza delle firme digitali:
- Nella demo live abbiamo dovuto usare --allow-unsigned-rpm. In produzione e' un rischio critico: i pacchetti RPM e DEB possono contenere scriptlet di manutenzione eseguiti come root.
- Installare un pacchetto non firmato equivale a lanciare curl ... | sudo bash.
- Differenze architetturali nella verifica:
  1. APT verifica prima i metadati del repository; i singoli file .deb sono convalidati tramite i digest sha256 nel file Release firmato.
  2. RPM firma direttamente header e payload all'interno del file; zypper/rpm valida la firma contro le chiavi GPG del sistema.
  3. Flatpak verifica crittograficamente i commit e i sommari OSTree a ogni pull.
  4. AppImage supporta firme incorporate, ma l'avvio standard in spazio utente non esegue alcun controllo forzato.
- Tendenza moderna: Sigstore e cosign abilitano provenienza keyless per le release su GitHub, ma le distribuzioni continuano a pretendere anelli di chiavi GPG.

--

## SBOM: Il Paradosso della Supply Chain

* Nei linguaggi moderni (Rust, Go): lockfile deterministici (`Cargo.lock`, `go.sum`).
* **Nel C con CMake, non esiste un lockfile universale**:
  * `raylib` incorporata a build time via Git (`FetchContent`, archivio statico).
  * Stack di sistema (X11, OpenGL, glibc) risolto dinamicamente a runtime dalla distro.

<div class="fragment callout" style="margin-top: 25px;">
<strong>Il Paradosso dell'SBOM in C</strong>: Le dipendenze sono divise tra tempo di compilazione e tempo di installazione. Un SBOM completo non si deduce dal codice sorgente: richiede l'osservazione della build dentro un build service isolato.
</div>

Note:
La realta' dell'SBOM nel software di sistema:
- Gli sviluppatori abituati a Rust, Go o al Python moderno danno per scontati i lockfile che bloccano ogni dipendenza transitiva a un digest crittografico.
- Nel C con CMake non esiste alcun lockfile universale.
- In ocio il grafo delle dipendenze e' spezzato in due meta':
  1. Tempo di compilazione: raylib viene scaricata via Git (FetchContent) e collegata staticamente nel binario.
  2. Tempo di esecuzione: X11, OpenGL e libc sono totalmente assenti dal repository sorgente; vengono risolti dinamicamente dall'host al momento del lancio.
- E' impossibile generare una Software Bill of Materials accurata scansionando solo git. E' necessario catturare l'ambiente di build ermetico (SPDX / CycloneDX generati dentro OBS o Koji).

---

## Sintesi: Matrice delle Responsabilità

| Formato | Chi risolve le dipendenze | Accoppiamento Host | Modello |
|---|---|---|---|
| **Tarball** | Sviluppatore (statico) + Host (dinamico) | Indefinito / Fragile | `execve` diretto |
| **`.deb` / `.rpm`** | **Distribuzione** (SAT solver) | Totale | `execve` nativo su `/usr` |
| **AppImage** | **Bundle** (SquashFS payload) | Ridotto (glibc/FUSE) | Mount FUSE + `execve` |
| **Flatpak** | **Runtime Condiviso** (Freedesktop) | Disaccoppiato | Bubblewrap + Portali |
| **Container OCI** | **Immagine Userspace Completa** | Minimo (kernel/DRI) | Namespaces + cgroups |

<p class="text-info" style="margin-top: 25px;">
<em>Ogni scelta di packaging delega e distribuisce la responsabilità tra sviluppatore, maintainer e sistema operativo.</em>
</p>

Note:
La conclusione fondamentale dell'analisi dei formati:
- Non esiste un formato universalmente "migliore". Ognuno rappresenta un compromesso ingegneristico su chi si fa carico della complessita':
  1. Delega alla distribuzione (RPM/DEB): I maintainer e i risolutori SAT pagano il costo del packaging. Il sistema ottiene librerie condivise in RAM, payload ridotti e patch di sicurezza unificate.
  2. Bundle a file singolo (AppImage): Lo sviluppatore paga includendo le librerie; l'utente ottiene massima semplicita' d'avvio senza installazione.
  3. Runtime in sandbox (Flatpak): Flathub e i curatori del runtime gestiscono lo stack di base; chi impacchetta definisce i varchi dei portali.
  4. Container (OCI): Isolamento totale, al prezzo di trasportare interi userspace di sistema operativo.
- Conservazione della complessita': Il packaging non cancella mai la complessita', decide solo quale attore della catena deve sostenerla.

--

## Metriche

| Soluzione | Spazio su Disco (Payload + Deps) | Overhead Avvio a Freddo |
|---|---|---|
| **Raw Binary** | *[TBD: size MB]* | 0 ms (Baseline: *[TBD ms]*) |
| **Native .rpm / .deb** | *[TBD: size KB]* (+ librerie host) | ~0 ms (Shared in pagecache) |
| **Standalone Tarball** | *[TBD: size MB]* | ~0 ms |
| **AppImage** | *[TBD: size MB]* | +*[TBD ms]* (FUSE &amp; SquashFS) |
| **Flatpak** | *[TBD: size MB]* (+ base ~500 MB) | +*[TBD ms]* (bwrap &amp; IPC portali) |
| **OCI Container** | *[TBD: size MB]* | +*[TBD ms]* (Overlayfs &amp; rootless) |
| **Source Build** | *[TBD: size MB]* (+ toolchain) | 0 ms (post-compilazione) |

<p style="margin-top: 25px;">
<strong>Trade-off sistemistico:</strong> Portabilità e isolamento si pagano in tempi di inizializzazione e spazio su disco.
</p>

--

## Confini e Scelte di Scope

<div class="grid-2">
<div>

### Cosa Abbiamo Escluso
* **Snap**: Demone `snapd` e dipendenza da AppArmor
* **Nix / Guix**: Store puramente funzionale (`/nix/store`)
* **Arch / AUR**: Ricette di build, non binari distribuiti

</div>
<div>

### La Trappola della GLIBC
* AppImage compilati su distro recenti falliscono su LTS datate
* **Soluzione**: Compilare i bundle dentro container LTS storici

</div>
</div>

<p class="text-warn fragment" style="margin-top: 30px;">
<em>Sono scelte sistemistiche e confini precisi, non dimenticanze.</em>
</p>

Note:
Spiegare i confini deliberati del talk:
- Snap: Richiede un demone privilegiato persistente (snapd), e' vincolato all'infrastruttura di Canonical e poggia su patch AppArmor del kernel non uniformi su tutte le distro.
- Nix e GNU Guix: Sistemi dichiarativi affascinanti, ma il loro modello di store (/nix/store) e' un paradigma completamente a parte che merita una presentazione dedicata.
- Arch AUR: Ricette PKGBUILD per compilare da sorgente sulla macchina utente, non distribuzione di artefatti binari pronti.
- La lezione sulla baseline GLIBC: Ribadire che includere librerie applicative non protegge dalla libreria C dell'host. Compilare un AppImage su Tumbleweed o Fedora 41 ne impedisce l'avvio su Ubuntu 20.04 o SLE 15. La best practice industriale e' compilare dentro container Debian oldstable o CentOS 7.

---

## Domande e Risposte

<div class="grid-2" style="align-items: center; max-width: 700px; margin: 40px auto 0 auto;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&amp;data=https://michelepagot.github.io/packathon/" alt="QR Code Repository" style="border-radius: 8px; border: 2px solid rgba(255,255,255,0.3);" />
  <div>
    <p><strong>Slide e Codice:</strong></p>
    <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
    <p><a href="https://github.com/michelepagot/packathon" target="_blank">github.com/michelepagot/packathon</a></p>
    <p class="text-success" style="margin-top: 20px;"><strong>Q&amp;A Aperto</strong></p>
  </div>
</div>

Note:
Conclusione della presentazione:
- Ringraziare il pubblico per l'attenzione.
- Ricordare che tutte le ricette di build in container, gli spec file e gli script di demo sono open source e riproducibili nel repository.
- Aprire lo spazio per le domande su packaging nativo (RPM/DEB), bundle portabili (AppImage), sandbox desktop (Flatpak) o build service (OBS).

