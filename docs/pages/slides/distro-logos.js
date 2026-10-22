/* Distro Logo Background Spawner
 *
 * When a fragment with data-fragments="logos" is revealed, the distro names
 * mentioned in that line are matched against a known logo map, and the
 * corresponding logo images are spawned at random positions in the
 * #logoLayer background layer (between the box canvas and the slides).
 *
 * All logo PNGs are normalized to 240px height. The CSS sets
 * height: 120px (half of native) so every logo renders at the same
 * visual size regardless of its native width.
 *
 * Logos are cumulative: each revealed line adds its logos, building a
 * "wall of distros" across the slide. The layer is cleared when leaving
 * the slide.
 */
(function () {
  "use strict";

  // Distro name -> logo file. Keys are matched case-insensitively
  // against the revealed line's text. All files are 240px-tall PNGs.
  const LOGO_MAP = {
    "red hat": "image/redhat.png",
    "rhel": "image/redhat.png",
    "fedora": "image/fedora.png",
    "centos stream": "image/centos-stream.png",
    "rocky": "image/rocky-linux.png",
    "almalinux": "image/almalinux.png",
    "oracle": "image/oracle-linux.png",
    "sle": "image/suse-linux-enterprise.png",
    "suse": "image/suse-linux-enterprise.png",
    "opensuse": "image/opensuse.png",
    "tumbleweed": "image/opensuse.png",
    "leap": "image/opensuse.png",
    "mageia": "image/mageia.png",
    "openmandriva": "image/openmandriva.png",
    "pclinuxos": "image/pclinuxos.png",
    "rosa": "image/rosa-linux.png",
    "tizen": "image/tizen.png",
    "sailfish": "image/sailfish-os.png",
    "qubes": "image/qubes-os.png",
    "asahi": "image/asahi-linux.png",
    "cbl-mariner": "image/cbl-mariner.png",
    "mariner": "image/cbl-mariner.png",
    "asianux": "image/asianux.png",
    "red star": "image/red-star-os.png",
    "debian": "image/debian.png",
    "ubuntu": "image/ubuntu.png",
    "linux mint": "image/linuxmint.png",
    "mint": "image/linuxmint.png",
    "kali": "image/kali.png",
    "deepin": "image/deepin.png",
    "tails": "image/tails.png",
    "raspberry": "image/raspberry.png",
    "devuan": "image/devuan.png",
    "zorin": "image/zorin.png",
    "pop!_os": "image/popos.png",
    "pop os": "image/popos.png",
    "elementary": "image/elementary.png",
    "parrot": "image/parrot.png",
    "mx linux": "image/mxlinux.png",
    "whonix": "image/whonix.png",
    "sparky": "image/sparky.png",
    "pureos": "image/pureos.png",
    "knoppix": "image/knoppix.png",
    "trisquel": "image/trisquel.png",
    "antix": "image/antix.png",
    "q4os": "image/q4os.png",
    "peppermint": "image/peppermint.png",
    "bodhi": "image/bodhi.png",
    "siduction": "image/siduction.png",
    "webconverger": "image/webconverger.png",
  };

  // Per-logo height overrides in CSS pixels. Logos not listed here use
  // the default 120px (set in CSS). Square icon logos look small next to
  // wide wordmarks, so they get a larger height.
  const LOGO_HEIGHTS = {
    "image/asahi-linux.png": 180,
  };

  const layer = document.getElementById("logoLayer");
  if (!layer || typeof Reveal === "undefined") return;

  function resolveSrc(src) {
    return new URL(src, window.location.href).href;
  }

  function logosForText(text) {
    const lower = text.toLowerCase();
    const found = [];
    const seen = new Set();
    for (const [name, file] of Object.entries(LOGO_MAP)) {
      if (lower.includes(name) && !seen.has(file)) {
        seen.add(file);
        found.push(file);
      }
    }
    return found;
  }

  // Map from fragment element -> array of spawned logo <img> nodes.
  const fragmentLogos = new WeakMap();

  // Track positions of all currently visible logos to avoid overlaps.
  const placedLogos = []; // [{ left, top }]

  // Minimum center-to-center distance (in viewport %) to avoid overlap.
  const MIN_DIST = 18;

  function findPosition() {
    for (let attempt = 0; attempt < 20; attempt++) {
      const left = 1 + Math.random() * 82; // 1%..83%
      const top = 4 + Math.random() * 76; // 4%..80%

      // Reject positions inside the central text zone (ellipse).
      const dx = (left - 50) / 25;
      const dy = (top - 50) / 30;
      if (dx * dx + dy * dy <= 1) continue;

      // Reject positions too close to an already-placed logo.
      let tooClose = false;
      for (const p of placedLogos) {
        const ddx = left - p.left;
        const ddy = top - p.top;
        if (Math.sqrt(ddx * ddx + ddy * ddy) < MIN_DIST) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;

      return { left, top };
    }
    // Fallback: accept a random position if no clear spot found.
    return {
      left: 1 + Math.random() * 82,
      top: 4 + Math.random() * 76,
    };
  }

  function spawnLogo(src, fragKey) {
    const img = document.createElement("img");
    img.className = "distro-logo";
    img.src = resolveSrc(src);
    img.alt = "";
    img.setAttribute("aria-hidden", "true");

    const pos = findPosition();
    const tilt = (Math.random() * 24 - 12).toFixed(1); // -12deg..+12deg

    img.style.left = pos.left + "%";
    img.style.top = pos.top + "%";
    img.style.transform = "rotate(" + tilt + "deg)";
    img.style.transformOrigin = "center center";
    if (LOGO_HEIGHTS[src]) {
      img.style.height = LOGO_HEIGHTS[src] + "px";
    }

    placedLogos.push({ left: pos.left, top: pos.top });
    layer.appendChild(img);

    if (!fragmentLogos.has(fragKey)) {
      fragmentLogos.set(fragKey, []);
    }
    fragmentLogos.get(fragKey).push(img);

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        img.classList.add("shown");
      });
    });
  }

  function removeFragmentLogos(fragKey) {
    const logos = fragmentLogos.get(fragKey);
    if (logos) {
      for (const img of logos) {
        // Remove the position from placedLogos.
        const idx = placedLogos.findIndex(
          (p) => p.left === parseFloat(img.style.left) && p.top === parseFloat(img.style.top)
        );
        if (idx !== -1) placedLogos.splice(idx, 1);
        img.remove();
      }
      fragmentLogos.delete(fragKey);
    }
  }

  function clearLayer() {
    layer.innerHTML = "";
    placedLogos.length = 0;
  }

  Reveal.on("fragmentshown", (event) => {
    const frag = event.fragment;
    if (!frag || frag.getAttribute("data-fragments") !== "logos") return;

    const li = frag.closest("li") || frag;
    const text = li.textContent || "";
    const logos = logosForText(text);
    for (const src of logos) {
      spawnLogo(src, frag);
    }
  });

  Reveal.on("fragmenthidden", (event) => {
    const frag = event.fragment;
    if (!frag || frag.getAttribute("data-fragments") !== "logos") return;
    removeFragmentLogos(frag);
  });

  Reveal.on("slidechanged", () => {
    clearLayer();
  });
})();
