# Packathon

### Packaging e Distribuzione Software su Linux

<p style="color: #888; font-size: 0.7em; margin-top: 30px;">Linux Day Trieste 2026</p>

Note:
Lasciare ocio in esecuzione su un secondo schermo o finestra.
Gag di apertura:
"Gli organizzatori mi hanno invitato qui oggi per parlarvi di packaging e release engineering. Ma siamo onesti: io in realtà sono qui per mostrarvi l'applicazione vibecodata in 15 minuti che vi cambierà per sempre la vita."
Mostrare l'occhio che traccia il mouse, premere V per la versione.
"Ora che l'avete vista, so che la volete tutti. Ma non ho un server o una pipeline, quindi ho deciso di distribuirla alla vecchia maniera."
Estrarre il floppy disk da 3.5 pollici dalla borsa:
"Se a fine talk mi lasciate il vostro indirizzo postale e un francobollo, ve la spedisco per posta."

---

## Slide

<div style="margin-top: 30px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 20px;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=https://michelepagot.github.io/packathon/" alt="QR Code Slide" style="border-radius: 12px; border: 3px solid rgba(255,255,255,0.4);" />
  <p style="font-size: 0.85em;"><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
</div>

Note:
Pausa per permettere al pubblico di inquadrare il QR code.

---

## Speaker

<div style="margin-top: 40px; font-size: 1.1em; line-height: 1.8;">

* **Michele Pagot**
* **SUSE**: Quality Engineering (QE)
* GitHub: [`@michelepagot`](https://github.com/michelepagot) · [`@mpagot`](https://github.com/mpagot)

</div>

---

## Disclaimer

<div style="font-size: 0.85em; text-align: left; margin-top: 30px; line-height: 1.8;">

* Non sono un package maintainer di professione.
* Indagine ingegneristica sui vincoli del packaging a monte prima dei banchi di test.

</div>

Note:
"Non sono un package maintainer di professione. Lavoro all'estremità della pipeline: test, validazione e analisi degli output di rilascio su sistemi completi. Questo talk nasce per capire cosa succede a monte prima che il software arrivi sui nostri banchi di test."

---

## Agenda

<!-- .slide: style="font-size: 0.68em;" -->

<div style="display: flex; gap: 50px; text-align: left; max-width: 900px; margin: 30px auto 0 auto; line-height: 1.8;">
<div style="flex: 1;">

1. **Censimento**
2. **Prospettive**
3. **Dipendenze**
4. **Formati**
5. **Delega**: RPM &amp; DEB *(Demo)*

</div>
<div style="flex: 1;">

6. **AppImage**, **Flatpak**, **Permessi**
7. **Rilascio** &amp; **Aggiornamenti**
8. **Firme** &amp; **SBOM**
9. **Sintesi**, **Metriche**, **Q&amp;A**

</div>
</div>

---

## Censimento

<!-- .slide: style="font-size: 0.88em;" -->

<ol style="line-height: 1.8;">
  <li class="fragment">Chi usa Linux quotidianamente?</li>
  <li class="fragment">Chi usa esclusivamente i repository ufficiali?<br>
  <small style="color: #aaa;">(APT, Zypper, DNF, Pacman, AUR... Emerge, Slackpkg, urpmi)</small></li>
  <li class="fragment">Chi usa formati universali: Flatpak, AppImage o Snap?</li>
  <li class="fragment"><code>curl | sh</code></li>
  <li class="fragment">Chi compila regolarmente da sorgenti?<br>
  <small style="color: #aaa;">(<code>git clone &amp;&amp; cmake &amp;&amp; make &amp;&amp; sudo make install</code>)</small></li>
</ol>

Note:
Scandire le 5 domande guardando la sala:
1. 100% mani.
2. Repo ufficiali: fiducia cieca nei maintainer.
3. Flatpak/AppImage: indipendenza o resa alle dipendenze.
4. curl | sh: pragmatismo vs sicurezza della supply chain.
5. Sorgenti: i puristi di /usr/local.

---

## Prospettive

<div style="font-size: 1.2em; line-height: 2.2; margin-top: 40px; text-align: left; max-width: 500px; margin-left: auto; margin-right: auto;">

* **Utilizzatore**
* **Sviluppatore**
* **Maintainer**

</div>

Note:
Presentare le tre prospettive una alla volta tramite i fragment:

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

---

## Dipendenze

> *"Sul mio computer (compila e) va"*

<div style="font-size: 0.78em; text-align: left; margin-top: 25px;">

<div class="fragment">

```text
/ocio: error while loading shared libraries: libOpenGL.so.0:
cannot open shared object file: No such file or directory
$ echo $?
127
```

</div>

<div class="fragment" style="margin-top: 20px;">

```text
$ ldd ./ocio
    linux-vdso.so.1 (0x00007ffe315f6000)
    libm.so.6 => /lib64/libm.so.6 (0x00007f9c8f2b0000)
    libOpenGL.so.0 => not found
    libGLX.so.0 => not found
    libc.so.6 => /lib64/libc.so.6 (0x00007f9c8f0b0000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f9c8f3b0000)
```

</div>

</div>

Note:
Comando di test in container minimale:
$ podman run --rm -v ./build/bin/ocio:/ocio:ro,Z registry.opensuse.org/opensuse/tumbleweed:latest /ocio

La realta' sistemistica:
- Un binario ELF dinamico e' un contratto incompleto con l'OS.
- execve() ha successo: il kernel mappa il binario e passa il controllo all'interprete indicato in PT_INTERP (/lib64/ld-linux-x86-64.so.2).
- Il dynamic linker, in userspace, scansiona le voci DT_NEEDED nella sezione dinamica ELF.
- Risolve i percorsi: RPATH/RUNPATH, /etc/ld.so.cache, sottodirectory glibc-hwcaps, /lib64, /usr/lib64.
- La prima libreria mancante (libOpenGL.so.0) fa stampare l'errore a ld.so e chiama exit_group(127).
- Il codice C non e' mai partito: il processo e' terminato nel loader, prima di main(). Il kernel ha fatto il suo lavoro; il contratto userspace e' stato violato. Il packaging e' la disciplina che garantisce che questo contratto sia soddisfatto ovunque.

---

## Formati

<div style="font-size: 0.82em; margin-top: 30px;">

| Target | Meccanismo |
|---|---|
| **Standalone Tarball** | Archivio compresso (`.tar.gz`) con asset e `.desktop` |
| **RPM (`.rpm`)** | Payload CPIO per Fedora/openSUSE/RHEL |
| **Debian (`.deb`)** | Archivio `ar` standard via CPack |
| **AppImage** | File unico con SquashFS montato via FUSE |
| **Flatpak** | Sandbox Bubblewrap su runtime Freedesktop |
| **Container OCI** | Immagine userspace completa eseguita da Podman |
| **Compilazione sorgente** | Matrice CMake controllata (`FETCH`, `SYSTEM`, `LOCAL`) |

</div>

---

## Dentro un RPM

<div style="font-size: 0.6em; text-align: left; margin-top: 15px;">

```text
$ file ocio-0.1.0-1.x86_64.rpm
ocio-0.1.0-1.x86_64.rpm: RPM v3.0 bin i386/x86_64
```

```text
+--------+-------------+-------------+------------------------------+
| Lead   | Signature   | Header      | Payload                      |
| magic  | digest,     | nome, deps, | archivio cpio, zstd          |
|        | GPG (none)  | elenco file | i file effettivi             |
+--------+-------------+-------------+------------------------------+
```

<div class="fragment">

```text
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | file -
/dev/stdin: ASCII cpio archive (SVR4 with no CRC)
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | cpio -idmv
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```

</div>
</div>

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

---

## Dentro un RPM

<div style="display: flex; gap: 20px; font-size: 0.6em; margin-top: 20px; text-align: left;">
<div style="flex: 1;">
<h4>Payload: file</h4>

```text
$ rpm -qlp ocio-0.1.0-1.x86_64.rpm
/usr/bin/ocio
/usr/share/applications/ocio.desktop
/usr/share/icons/hicolor/256x256/apps/ocio.png
/usr/share/icons/hicolor/scalable/apps/ocio.svg
/usr/share/metainfo/org.packathon.ocio.metainfo.xml
```

</div>
<div class="fragment" style="flex: 1;">
<h4>Header: metadati</h4>

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm
libOpenGL.so.0()(64bit)
libGLX.so.0()(64bit)
libc.so.6(GLIBC_2.34)(64bit)
libm.so.6(GLIBC_2.43)(64bit)
...
$ rpm -qp --provides ocio-0.1.0-1.x86_64.rpm
ocio = 0.1.0-1
application(ocio.desktop)
```

</div>
</div>

Note:
rpm puo' interrogare entrambe le meta' del file senza installarlo (-p = file di pacchetto).
Payload (directory omesse dall'elenco):
- /usr/bin/ocio: il binario, in una directory gia' presente in $PATH.
- .desktop + icone: come l'app appare nel menu del desktop.
- metainfo XML: come i centri software (GNOME Software, Discover) la descrivono.
Header, sul fragment:
- Guardate i Requires: libOpenGL.so.0, libGLX.so.0. Questo e' esattamente l'elenco DT_NEEDED dall'errore di due slide fa.
- Nessuno ha scritto queste righe a mano. Il dependency generator di rpmbuild legge l'ELF (DT_NEEDED + versioni dei simboli glibc) e le scrive nell'header automaticamente.
- Provides: cosa offre questo pacchetto agli altri (un nome, una versione, un'applicazione desktop).
- Parcheggiamo GLIBC_2.43: ci torniamo nella slide Delega.

---

## Seguendo libOpenGL.so.0

<div style="font-size: 0.7em; text-align: left; margin-top: 25px;">

```text
$ readelf -d ocio | grep OpenGL                                  # il binario
 (NEEDED)  Shared library: [libOpenGL.so.0]
```

<div class="fragment" style="margin-top: 20px;">

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm | grep OpenGL        # il pacchetto
libOpenGL.so.0()(64bit)
```

</div>
</div>

<p class="fragment" style="margin-top: 30px; font-size: 0.85em;">
<strong>486 KB</strong> di pacchetto &rarr; <strong>36</strong> pacchetti &rarr; <strong>52.6 MiB</strong> di download
</p>

Note:
Seguiamo una singola stringa dal messaggio di errore fino al repository.
1. Il binario dice: ho bisogno di libOpenGL.so.0.
2. Il pacchetto lo ripete, in una forma che il package manager puo' interrogare.
3. Il repository risponde: libglvnd lo fornisce. Il nome dal messaggio di errore ora ha un proprietario.
4. Ma libglvnd ha i suoi requisiti (libX11, Mesa-dri), che hanno i loro, e cosi' via.
Risultato su un container Tumbleweed vanilla: 36 nuovi pacchetti (incluso ocio), 52.6 MiB di download, per un pacchetto di 486 KB.
Una frase sul solver, non di piu': "Alcuni requisiti hanno fornitori alternativi; scegliere un insieme coerente tra decine di migliaia di pacchetti e' un problema logico (SAT), e zypper lo risolve in millisecondi con libsolv." Approfondimento solo se richiesto nel Q&A.
Nota per utenti Fedora: l'equivalente di zypper se --provides e' dnf provides.

---

## Demo rpm

Installazione RPM in container openSUSE Tumbleweed *vanilla*:

```bash
$ podman run --rm -v "$PWD/dist/ocio-0.1.0-1.x86_64.rpm:/ocio.rpm:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    sh -c "zypper --non-interactive in --allow-unsigned-rpm /ocio.rpm && ocio --version"
```

<p style="margin-top: 25px; font-size: 0.85em; text-align: left; color: #ffb74d;">* <code>--allow-unsigned-rpm</code></p>

<button class="terminal-btn" onclick="openLiveTerminal()">💻 Apri Terminale Live</button>

Note:
[Terminale Live]: Passare alla scheda del terminale a tutto schermo con Ctrl+Tab (o Alt+Tab).
Eseguire la demo live o mostrare il comando a terminale.
Cosa fa zypper, in ordine (visibile nel suo output):
- Resolve: calcola i 36 pacchetti.
- Retrieve: li scarica (ocio stesso dalla cache dei file RPM locali).
- Verify: controlla le firme. Qui non puo': il nostro pacchetto non e' firmato.
- Check for file conflicts: nessun pacchetto puo' possedere lo stesso percorso.
- Install: scompatta i file in /usr, registra ogni file nel database RPM.
Dettaglio critico dell'asterisco: --allow-unsigned-rpm. rpm -qi ocio mostra "Signature: (none)" e "Build Host: e246f0b7ceaf" (un ID container casuale): nulla prova chi abbia costruito questo pacchetto. Questo non include scriptlet (rpm -qp --scripts e' vuoto), ma il prossimo RPM non firmato potrebbe averne, e gli scriptlet girano come root. Anticipare la sezione Firme.

---

## Dopo l'installazione

<div style="display: flex; gap: 20px; font-size: 0.58em; margin-top: 20px; text-align: left;">
<div style="flex: 1;">
<h4>Risolto</h4>

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

</div>
<div class="fragment" style="flex: 1;">
<h4>Registrato</h4>

```text
$ rpm -qf /usr/lib64/libOpenGL.so.0
libglvnd-1.7.0-2.4.x86_64
$ rpm -V ocio && echo clean
clean
$ rpm -e --test libglvnd
error: Failed dependencies:
  libOpenGL.so.0()(64bit) is needed by
    (installed) ocio-0.1.0-1.x86_64
  ...
```

</div>
</div>

Note:
A sinistra: lo stesso ldd della slide Dipendenze. Ogni "not found" ora e' un percorso in /lib64. Il loader segue anche le dipendenze delle librerie stesse (libGLdispatch, libX11, libxcb).
A destra: installare significa copiare file piu' tenere traccia.
- rpm -qf: ogni file sul sistema ha un proprietario noto.
- rpm -V: verifica i file installati rispetto ai digest nel database. Momento live facoltativo: aggiungere un byte a ocio.desktop e rieseguire, l'output diventa "S.5....T. /usr/share/applications/ocio.desktop" (Size, digest (5), mTime modificati).
- rpm -e --test: il database rifiuta di rimuovere una libreria di cui altri hanno ancora bisogno. Questo e' cio' che impedisce al sistema di rompersi.

---

## Avvio

<div style="font-size: 0.8em; text-align: left; margin-top: 25px;">

`$ ocio`

1. **Shell**: ricerca in `$PATH` &rarr; `/usr/bin/ocio` <small>(`command -v ocio`)</small>
2. **Kernel**: `execve()` &rarr; `PT_INTERP` &rarr; `ld.so`
3. **ld.so**: `DT_NEEDED` &rarr; `/lib64/libOpenGL.so.0` trovato
4. `main()`

</div>

<p class="fragment" style="margin-top: 25px; font-size: 0.85em;">
Stesso percorso dell'esecuzione fallita. Il package manager <strong>non interviene</strong> all'avvio.
</p>

<p class="fragment" style="margin-top: 15px; font-size: 0.85em; color: #4fc3f7;">
<em>Chi altro è presente quando l'applicazione parte?</em>
</p>

Note:
Rispondere esplicitamente alla domanda: cosa fa l'OS quando eseguiamo un'app installata da un RPM? Niente di speciale.
- La shell trova il binario attraverso $PATH (/usr/bin e' sempre presente).
- Il kernel lo carica e passa il controllo al dynamic linker, esattamente come nell'esecuzione fallita.
- L'unica differenza: questa volta i file esistono, perche' il package manager li ha posizionati in precedenza.
- RPM e' un installer e un contabile, non un runtime. Dopo l'installazione esce di scena.
L'ultima domanda e' il ponte verso la sezione successiva: con AppImage e Flatpak, qualcun altro e' presente all'avvio (un mount FUSE, una sandbox).

---

## Delega

* **Filosofia**: Il pacchetto trasporta solo il payload; dipendenze delegate alla distribuzione.

<div class="fragment" style="display: flex; gap: 20px; font-size: 0.78em; margin-top: 25px; text-align: left;">
<div style="flex: 1; border-left: 3px solid #81c784; padding-left: 15px;">
<h4>Vantaggi</h4>
<ul>
  <li>Payload minimo: 486 KB (52.6 MiB delegati).</li>
  <li>Librerie condivise: un solo <code>libglvnd</code>, patchato una volta per ogni app.</li>
  <li>Proprietà &amp; verifica: <code>rpm -qf</code>, <code>rpm -V</code>.</li>
</ul>
</div>
<div style="flex: 1; border-left: 3px solid #e57373; padding-left: 15px;">
<h4>Vincoli</h4>
<ul>
  <li>Accoppiamento ABI: <code>libm.so.6(GLIBC_2.43)</code>.</li>
  <li>Policy di packaging rigorose (FHS, <code>%files</code>, scriptlet).</li>
  <li>Una build per ogni distro target.</li>
</ul>
</div>
</div>

Note:
Riepilogo: ogni punto si riferisce a qualcosa che il pubblico ha appena visto.
- 486 KB vs 52.6 MiB: la distribuzione porta il peso.
- libglvnd e' condiviso da ocio, Mesa e ogni altra applicazione GL (rpm -q --whatrequires libglvnd): una CVE viene risolta una volta per tutte.
- GLIBC_2.43 nei Requires: questo pacchetto si installa solo dove glibc >= 2.43 esiste. Compilato su Tumbleweed, e' inutilizzabile su una LTS piu' vecchia. Il prezzo della delega e' l'accoppiamento.

---

## DEB

<div style="font-size: 0.6em; text-align: left; margin-top: 15px;">

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

<div class="fragment">

```text
$ dpkg-deb -I ocio_0.1.0_amd64.deb | grep Depends
 Depends: libc6 (>= 2.17), libgl1, libx11-6
```

```text
$ dpkg-deb -c ocio_0.1.0_amd64.deb
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```

</div>
</div>

Note:
Come e' fatto un file .deb:
- Non usa formati proprietari: e' un archivio ar standard Unix (lo stesso formato delle librerie statiche .a).
- Contiene tre soli file:
  1. debian-binary: stringa di testo con la versione del formato ("2.0\n").
  2. control.tar: archivio compresso con i metadati (control, md5sums, scriptlet postinst/prerm).
  3. data.tar: archivio compresso contenente i file effettivi da installare sul filesystem.
- dpkg-deb -I: ispeziona i metadati di controllo. Guardate il Depends: libc6, libgl1, libx11-6. In Debian e' generato da dpkg-shlibdeps scansionando i simboli DT_NEEDED.
- dpkg-deb -c: elenca il contenuto di data.tar senza estrarlo.
- In un container vergine debian:bookworm-slim, apt-get install /ocio.deb risolve l'albero e scarica 40 pacchetti.

---

## Dialetti

<!-- .slide: style="font-size: 0.65em;" -->

| Dimensione | Ecosistema RPM | Ecosistema DEB |
|---|---|---|
| **Contenitore** | CPIO compresso (zstd/gzip) | Archivio `ar` (`control.tar` + `data.tar`) |
| **Tool basso livello** | `rpm` | `dpkg` |
| **Package manager** | `zypper` / `dnf` | `apt` |
| **Generatore deps** | `find-requires` (da `DT_NEEDED`) | `dpkg-shlibdeps` (file `symbols`) |
| **Ispezione payload** | `rpm -qlp FILE.rpm` | `dpkg-deb -c FILE.deb` |
| **Ispezione metadati** | `rpm -qp --requires FILE.rpm` | `dpkg-deb -I FILE.deb` |
| **Verifica integrità** | `rpm -V PACKAGE` | `debsums PACKAGE` |

Note:
Due dialetti, stesso principio ingegneristico:
- Sia RPM che DEB separano nettamente il payload dei file dai metadati di controllo.
- Entrambi usano generatori automatici per trasformare i requisiti ELF DT_NEEDED in dipendenze di pacchetto.
- Entrambi delegano la risoluzione a un gestore ad alto livello (zypper/dnf con libsolv, apt con il suo motore di scoring).
- Conclusione della sezione Delega: abbiamo visto come la distribuzione si fa carico del mondo. Ora vediamo la contromossa: chi rifiuta di delegare.

---

## AppImage

<div style="font-size: 0.78em; text-align: left; max-width: 800px; margin: 25px auto;">

* Runtime stub ELF + filesystem compresso **SquashFS**
* Montaggio in spazio utente tramite **FUSE** ed esecuzione `AppRun`
* Dipendenza da `glibc` host: compilare su distro recente rompe la compatibilita' all'indietro

```text
$ ./ocio-x86_64.AppImage --appimage-extract
$ ls -1 squashfs-root
AppRun
ocio
ocio.desktop
ocio.png
```

</div>

Note:
Come funziona AppImage:
- Il file e' un binario ELF (runtime stub) che incapsula un'immagine SquashFS compressa.
- All'avvio, il runtime monta il filesystem in spazio utente tramite FUSE e lancia AppRun.
- Non richiede permessi di root ne' installazione: si scarica e si esegue direttamente.
- Il limite di glibc: non include la libreria C ne' l'ABI del kernel. Se compilato su una distribuzione recente, fissa simboli GLIBC minimi che impediscono l'esecuzione su distribuzioni LTS piu' datate.
- Con l'opzione --appimage-extract il payload viene scompattato, consentendo l'uso anche dove FUSE non e' abilitato.

---

## Flatpak

<div style="font-size: 0.78em; text-align: left; max-width: 800px; margin: 25px auto;">

* Runtime condiviso versionato: `org.freedesktop.Platform`
* Isolamento di sistema tramite **Bubblewrap** (`bwrap`)
* Filesystem immutabile e riproducibile, disaccoppiato dall'host

```text
$ flatpak run --command=sh org.packathon.ocio
[org.packathon.ocio ~]$ ls /
app  bin  dev  etc  lib  lib64  proc  run  sys  usr  var
[org.packathon.ocio ~]$ which ocio
/app/bin/ocio
```

</div>

Note:
Come funziona Flatpak:
- Disaccoppiamento radicale dall'OS: l'applicazione non vede /usr della macchina host, ma un runtime condiviso versionato (Freedesktop Platform).
- Isolamento tramite Bubblewrap (bwrap): namespaces del kernel Linux (mount, PID, network, IPC) per creare un container desktop riproducibile.
- Struttura dei percorsi: /app contiene i file dell'applicazione, /usr contiene le librerie della runtime platform.
- Ponte verso la slide successiva: poiche' la sandbox e' isolata, per comunicare con schermo, GPU e audio dobbiamo richiedere esplicitamente i permessi nel file di manifest.

---

## Permessi

Non fidarsi dell'host impone la re-dichiarazione esplicita di ogni risorsa:

```yaml
# packaging/flatpak/org.packathon.ocio.yml
finish-args:
  - --socket=x11        # Display server X11
  - --socket=wayland    # Compositor Wayland
  - --device=dri        # Accelerazione GPU (/dev/dri)
  - --share=ipc         # Memoria condivisa (MIT-SHM)
```

* Nei container host (Podman):  
  `--net=host --ipc=host -v /tmp/.X11-unix:/tmp/.X11-unix --device /dev/dri`
* **Conseguenza**: La complessità si sposta dai simboli dinamici alla negoziazione di canali IPC e portali D-Bus.

---

## Rilascio

> *"CPack genera cinque formati in una riga. Ma un file non è un canale di distribuzione."*

<div class="fragment" style="margin-top: 20px; text-align: left; font-size: 0.8em; line-height: 1.8;">
<h4>CPack vs Build Service (OBS / Koji)</h4>
<ul>
  <li><strong>CPack</strong>: Compila sull'host dello sviluppatore; "avvelena" l'header RPM con percorsi e librerie locali.</li>
  <li><strong>Open Build Service (OBS)</strong>:
    <ul>
      <li>Compilazione in <strong>chroot isolate dalla rete</strong>.</li>
      <li>Ricompilazione automatica a cascata sui cambi di dipendenze.</li>
      <li>Verifica vincolante con <code>%check</code> e policy audit (<code>rpmlint</code>).</li>
      <li>Firma GPG automatizzata gestita dal server di build.</li>
    </ul>
  </li>
</ul>
</div>

---

## Aggiornamenti

La capacità di aggiornamento dipende dal **canale**, non dal formato:

<ul style="font-size: 0.82em; text-align: left; line-height: 1.8;">
  <li class="fragment"><strong><code>.deb</code> / <code>.rpm</code> via repo</strong>: Aggiornamenti automatici dell'OS (<code>apt upgrade</code>, <code>zypper dup</code>).</li>
  <li class="fragment"><strong>File installato a mano (<code>dpkg -i</code> / <code>rpm -i</code>)</strong>: Artefatto orfano; nessuna patch futura.</li>
  <li class="fragment"><strong>Flatpak via Flathub</strong>: Repository <strong>OSTree</strong>; delta statici a blocchi (aggiornamenti atomici).</li>
  <li class="fragment"><strong>AppImage</strong>: Statico; richiede metadati <code>.upd_info</code> nella sezione ELF per abilitare <code>zsync</code>.</li>
</ul>

<p class="fragment" style="margin-top: 25px; font-size: 0.8em; color: #ff8a80;">
<em>Un binario privo di canale di aggiornamento è un rischio di sicurezza permanente.</em>
</p>

---

## Firme

Perché `--allow-unsigned-rpm` è inaccettabile: nessuna prova di origine e gli scriptlet (quando presenti) vengono eseguiti come **root**.

<div style="font-size: 0.78em; text-align: left; margin-top: 20px;">

| Ecosistema | Livello di Firma | Validazione a Runtime |
|---|---|---|
| **APT** | Metadati repo (`Release.gpg`) | Verifica obbligatoria pre-unpack |
| **RPM** | Header pacchetto + `repomd.xml` | Verifica GPG su keyring di sistema |
| **Flatpak** | Commit &amp; Summary in OSTree | Verifica crittografica ad ogni pull |
| **AppImage** | Sezione ELF (`--appimage-signature`) | **Nessuna verifica automatica** a runtime |

</div>

<p class="fragment" style="margin-top: 20px; font-size: 0.8em;">
<strong>Scenario 2026</strong>: <em>Sigstore / Keyless</em> (OIDC) per release upstream; GPG tradizionale ancora obbligatorio per i package manager di sistema.
</p>

---

## SBOM

* Nei linguaggi moderni (Rust, Go): lockfile deterministico (`Cargo.lock`, `go.sum`).
* **Nel C con CMake, il lockfile universale non esiste**:
  * `raylib` scaricata a build time via Git (`FetchContent`, statica).
  * Stack X11/OpenGL/glibc risolto a run-time dalla distribuzione.

<div class="fragment" style="margin-top: 20px; text-align: left; font-size: 0.82em; background: rgba(255,255,255,0.05); padding: 15px; border-radius: 8px;">
<p>L'SBOM in C è spezzata tra build time e run time. Solo un build service con chroot isolata e osservabile (es. OBS) può tracciare l'intero albero reale delle dipendenze.</p>
</div>

---

## Sintesi

<div style="font-size: 0.72em;">

| Formato | Chi risolve le dipendenze | Accoppiamento Host | Modello |
|---|---|---|---|
| **Tarball** | Sviluppatore (statico) + Host (dinamico) | Indefinito / Fragile | `execve` diretto |
| **`.deb` / `.rpm`** | **Distribuzione** (SAT solver) | Totale | `execve` nativo su `/usr` |
| **AppImage** | **Bundle** (SquashFS payload) | Ridotto (glibc/FUSE) | Mount FUSE + `execve` |
| **Flatpak** | **Runtime Condiviso** (Freedesktop) | Disaccoppiato | Bubblewrap + Portali |
| **Container OCI** | **Immagine Userspace Completa** | Minimo (kernel/DRI) | Namespaces + cgroups |

</div>

<p style="margin-top: 25px; font-size: 0.8em; color: #4fc3f7;">
<em>Ogni formato sposta la responsabilità tecnica tra sviluppatore, maintainer e sistema.</em>
</p>

---

## Metriche

<!-- .slide: style="font-size: 0.75em;" -->

<div style="font-size: 0.75em;">

| Soluzione | Spazio su Disco (Payload + Deps) | Overhead Avvio a Freddo |
|---|---|---|
| **Raw Binary** | *[TBD: size MB]* | 0 ms (Baseline: *[TBD ms]*) |
| **Native .rpm / .deb** | *[TBD: size KB]* (+ librerie host) | ~0 ms (Shared in pagecache) |
| **Standalone Tarball** | *[TBD: size MB]* | ~0 ms |
| **AppImage** | *[TBD: size MB]* | +*[TBD ms]* (FUSE &amp; SquashFS) |
| **Flatpak** | *[TBD: size MB]* (+ base ~500 MB) | +*[TBD ms]* (bwrap &amp; IPC portali) |
| **OCI Container** | *[TBD: size MB]* | +*[TBD ms]* (Overlayfs &amp; rootless) |
| **Source Build** | *[TBD: size MB]* (+ toolchain) | 0 ms (post-compilazione) |

</div>

<p style="margin-top: 25px; font-size: 0.85em; text-align: left;">
<strong>Trade-off sistemistico:</strong> Portabilità e isolamento si pagano in tempi di inizializzazione e spazio su disco.
</p>

---

## Limiti

<div style="font-size: 0.82em; text-align: left; line-height: 1.8;">

* **Formati esclusi**:
  * **Snap**: dipendenza da `snapd`, AppArmor accoppiato a patch kernel Ubuntu.
  * **Nix / Guix**: store puramente funzionale (`/nix/store`), paradigma radicalmente differente.
  * **Arch / AUR**: ricette di build per l'utente, non artefatti precompilati.
* **Il vincolo glibc in AppImage**:
  * Compilare su distro recente alza i simboli `GLIBC_2.XX` minimi: il bundle fallisce su sistemi più conservativi.
  * Soluzione: build containerizzati su baseline LTS datate.

</div>

<p style="margin-top: 25px; font-size: 0.82em; color: #ffb74d;">
<em>Non sono sviste: sono i confini fisici del rilascio software su Linux.</em>
</p>

---

## Q&A

<div style="display: flex; justify-content: center; align-items: center; gap: 50px; margin-top: 35px;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://michelepagot.github.io/packathon/" alt="QR Code Repository" style="border-radius: 8px; border: 2px solid rgba(255,255,255,0.3);" />
  <div style="text-align: left; font-size: 0.85em;">
    <p><strong>Slide &amp; Codice:</strong></p>
    <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
    <p><a href="https://github.com/michelepagot/packathon" target="_blank">github.com/michelepagot/packathon</a></p>
    <p style="margin-top: 20px; color: #81c784;"><strong>Q&amp;A aperto</strong></p>
  </div>
</div>
