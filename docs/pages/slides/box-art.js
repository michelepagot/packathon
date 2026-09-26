/* Procedural Cardboard Box Engine */
class Math3D {
  static sub(a, b) { return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z }; }
  static add(a, b) { return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z }; }
  static scale(a, s) { return { x: a.x * s, y: a.y * s, z: a.z * s }; }
  static dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
  static cross(a, b) {
    return { x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x };
  }
  static normalize(a) {
    const len = Math.hypot(a.x, a.y, a.z);
    return len === 0 ? { x: 0, y: 0, z: 0 } : { x: a.x / len, y: a.y / len, z: a.z / len };
  }
  static rotateY(point, angleDeg) {
    const rad = angleDeg * Math.PI / 180;
    const cos = Math.cos(rad);
    const sin = Math.sin(rad);
    return {
      x: point.x * cos + point.z * sin,
      y: point.y,
      z: -point.x * sin + point.z * cos
    };
  }
  static rand(min, max) {
    return Math.random() * (max - min) + min;
  }
}

class Box {
  constructor(x, z, w, h, d, hue, sat, lit, visibleFaces) {
    this.w = w; this.h = h; this.d = d;
    this.x = x;
    this.y = h / 2; // Bottom lands at World Y=0
    this.z = z;

    this.hue = hue;
    this.sat = sat;
    this.lit = lit;

    this.hasFlap = Math.random() < 0.8;
    this.flapAxis = Math.random() < 0.5 ? 'x' : 'z';
    this.hasHole = Math.random() < 0.4;
    this.hasArrows = Math.random() < 0.4;
    this.detailFace = visibleFaces[Math.floor(Math.random() * visibleFaces.length)];
  }

  intersects(other, margin = 20) {
    const overlapX = Math.abs(this.x - other.x) < (this.w + other.w) / 2 + margin;
    const overlapZ = Math.abs(this.z - other.z) < (this.d + other.d) / 2 + margin;
    return overlapX && overlapZ;
  }

  uvToLocal(faceId, u, v) {
    if (faceId === 0) return { x: -u, y: v, z: -this.d / 2 };
    if (faceId === 1) return { x: u, y: v, z: this.d / 2 };
    if (faceId === 2) return { x: -this.w / 2, y: v, z: u };
    if (faceId === 3) return { x: this.w / 2, y: v, z: -u };
    return { x: 0, y: 0, z: 0 };
  }

  getFaces() {
    const hw = this.w / 2, hh = this.h / 2, hd = this.d / 2;
    const corners = [
      { x: -hw, y: -hh, z: -hd }, { x: hw, y: -hh, z: -hd },
      { x: hw, y: hh, z: -hd }, { x: -hw, y: hh, z: -hd },
      { x: -hw, y: -hh, z: hd }, { x: hw, y: -hh, z: hd },
      { x: hw, y: hh, z: hd }, { x: -hw, y: hh, z: hd }
    ];

    const faceDefs = [
      { id: 0, verts: [0, 3, 2, 1], type: 'front', litOffset: -15 },
      { id: 1, verts: [5, 6, 7, 4], type: 'back', litOffset: -15 },
      { id: 2, verts: [4, 7, 3, 0], type: 'left', litOffset: -15 },
      { id: 3, verts: [1, 2, 6, 5], type: 'right', litOffset: 0 },
      { id: 4, verts: [4, 0, 1, 5], type: 'bottom', litOffset: -20 },
      { id: 5, verts: [3, 7, 6, 2], type: 'top', litOffset: 15 }
    ];

    let faces = faceDefs.map(fd => {
      let finalLit = Math.max(10, Math.min(90, this.lit + fd.litOffset));
      return {
        id: fd.id,
        verts: fd.verts.map(i => corners[i]),
        fillColor: `hsl(${this.hue}, ${this.sat}%, ${finalLit}%)`,
        strokeColor: `hsl(${this.hue}, ${this.sat}%, ${Math.max(5, finalLit - 25)}%)`,
        decorations: []
      };
    });

    if (this.hasFlap) {
      let p1, p2;
      if (this.flapAxis === 'x') {
        p1 = { x: -hw, y: hh, z: 0 }; p2 = { x: hw, y: hh, z: 0 };
      } else {
        p1 = { x: 0, y: hh, z: -hd }; p2 = { x: 0, y: hh, z: hd };
      }
      faces[5].decorations.push({ type: 'line', verts: [p1, p2], color: faces[5].strokeColor });
    }

    if (this.hasHole || this.hasArrows) {
      let face = faces.find(f => f.id === this.detailFace);
      if (face) {
        let W = (this.detailFace === 1 || this.detailFace === 0) ? this.w : this.d;
        let holeCy = 0, arrowsCy = 0;

        if (this.hasHole && this.hasArrows) {
          holeCy = this.h * 0.15;
          arrowsCy = -this.h * 0.15;
        }

        if (this.hasHole) {
          let holeW = Math.min(W * 0.3, 50) / 2;
          let holeH = Math.min(this.h * 0.15, 20) / 2;
          let cut = Math.min(holeW, holeH) * 0.4;

          let uvs = [
            { u: -holeW + cut, v: holeCy - holeH }, { u: holeW - cut, v: holeCy - holeH },
            { u: holeW, v: holeCy - holeH + cut }, { u: holeW, v: holeCy + holeH - cut },
            { u: holeW - cut, v: holeCy + holeH }, { u: -holeW + cut, v: holeCy + holeH },
            { u: -holeW, v: holeCy + holeH - cut }, { u: -holeW, v: holeCy - holeH + cut }
          ];
          let localVerts = uvs.map(uv => this.uvToLocal(this.detailFace, uv.u, uv.v));
          face.decorations.push({ type: 'polygon', verts: localVerts, color: `hsl(${this.hue}, ${this.sat}%, 15%)` });
        }

        if (this.hasArrows) {
          let numArrows = Math.random() < 0.5 ? 1 : 2;
          let offsets = numArrows === 1 ? [0] : [-W * 0.15, W * 0.15];

          offsets.forEach(ox => {
            let trunk = [{ u: ox, v: arrowsCy - 15 }, { u: ox, v: arrowsCy + 15 }];
            let leftWing = [{ u: ox - 8, v: arrowsCy + 5 }, { u: ox, v: arrowsCy + 15 }];
            let rightWing = [{ u: ox + 8, v: arrowsCy + 5 }, { u: ox, v: arrowsCy + 15 }];

            [trunk, leftWing, rightWing].forEach(line => {
              let localVerts = line.map(uv => this.uvToLocal(this.detailFace, uv.u, uv.v));
              face.decorations.push({ type: 'line', verts: localVerts, color: 'rgba(20, 20, 20, 0.8)' });
            });
          });
        }
      }
    }
    return faces;
  }
}

class Renderer {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.boxes = [];
    this.sceneAngleY = 0;

    this.focalLength = 2000;
    this.cameraZ = 4000;
    this.cameraY = 800;

    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize() {
    if (!this.canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = this.canvas.getBoundingClientRect();
    const w = rect.width || (window.innerWidth * 0.5);
    const h = rect.height || (window.innerHeight * 0.5);

    this.canvas.width = w * dpr;
    this.canvas.height = h * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    if (this.boxes.length > 0) this.render();
  }

  projectRaw(worldPoint) {
    const dz = this.cameraZ - worldPoint.z;
    const scale = this.focalLength / Math.max(dz, 1);
    return {
      x: worldPoint.x * scale,
      y: -(worldPoint.y - this.cameraY) * scale,
      depth: dz
    };
  }

  generate() {
    if (!this.canvas) return;
    this.boxes = [];
    this.sceneAngleY = Math3D.rand(35, 55) * (Math.random() > 0.5 ? 1 : -1);
    const visibleFaces = this.sceneAngleY > 0 ? [1, 3] : [1, 2];
    const numBoxes = Math.floor(Math3D.rand(1, 4));

    for (let i = 0; i < numBoxes; i++) {
      let attempts = 0, validBox = null;

      while (!validBox && attempts < 500) {
        let w = Math3D.rand(120, 280);
        let h = Math3D.rand(120, 360);
        let d = Math3D.rand(120, 280);
        let x = Math3D.rand(-350, 350);
        let z = Math3D.rand(-350, 350);

        let hue = Math3D.rand(30, 40);
        let sat = Math3D.rand(40, 70);
        let lit = Math3D.rand(50, 70);

        let testBox = new Box(x, z, w, h, d, hue, sat, lit, visibleFaces);
        if (!this.boxes.some(b => testBox.intersects(b))) {
          validBox = testBox;
        }
        attempts++;
      }
      if (validBox) this.boxes.push(validBox);
    }
    this.render();
  }

  render() {
    if (!this.canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const cssW = this.canvas.width / dpr;
    const cssH = this.canvas.height / dpr;

    this.ctx.clearRect(0, 0, cssW, cssH);

    let allFaces = [];
    const cameraPos = { x: 0, y: this.cameraY, z: this.cameraZ };

    this.boxes.forEach(box => {
      const localFaces = box.getFaces();

      localFaces.forEach(face => {
        let rotatedVerts = face.verts.map(v => {
          let worldV = { x: v.x + box.x, y: v.y + box.y, z: v.z + box.z };
          return Math3D.rotateY(worldV, this.sceneAngleY);
        });

        let edge1 = Math3D.sub(rotatedVerts[1], rotatedVerts[0]);
        let edge2 = Math3D.sub(rotatedVerts[2], rotatedVerts[0]);
        let faceNormal = Math3D.normalize(Math3D.cross(edge1, edge2));

        let faceCenter = rotatedVerts.reduce((acc, v) => Math3D.add(acc, v), { x: 0, y: 0, z: 0 });
        faceCenter = Math3D.scale(faceCenter, 0.25);
        let viewDir = Math3D.normalize(Math3D.sub(cameraPos, faceCenter));

        if (Math3D.dot(faceNormal, viewDir) > 0) {
          let projectedRaw = rotatedVerts.map(v => this.projectRaw(v));
          let avgZ = projectedRaw.reduce((sum, p) => sum + p.depth, 0) / projectedRaw.length;

          let processedDecos = face.decorations.map(deco => {
            let rotDecoVerts = deco.verts.map(v => {
              let worldV = { x: v.x + box.x, y: v.y + box.y, z: v.z + box.z };
              return Math3D.rotateY(worldV, this.sceneAngleY);
            });
            return {
              type: deco.type,
              color: deco.color,
              projVerts: rotDecoVerts.map(v => this.projectRaw(v))
            };
          });

          allFaces.push({
            rawVerts: projectedRaw,
            avgZ: avgZ,
            fillColor: face.fillColor,
            strokeColor: face.strokeColor,
            decorations: processedDecos
          });
        }
      });
    });

    allFaces.sort((a, b) => b.avgZ - a.avgZ);

    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    allFaces.forEach(face => {
      face.rawVerts.forEach(v => {
        minX = Math.min(minX, v.x); maxX = Math.max(maxX, v.x);
        minY = Math.min(minY, v.y); maxY = Math.max(maxY, v.y);
      });
    });

    const contentW = maxX - minX;
    const contentH = maxY - minY;
    if (contentW === 0 || contentH === 0 || !isFinite(contentW)) return;

    const padding = Math.min(cssW, cssH) * 0.1;
    const frameScale = Math.min((cssW - padding * 2) / contentW, (cssH - padding * 2) / contentH);

    const offsetX = cssW / 2 - ((minX + maxX) / 2) * frameScale;
    const offsetY = cssH / 2 - ((minY + maxY) / 2) * frameScale;

    allFaces.forEach(face => {
      const frame = (v) => ({ x: v.x * frameScale + offsetX, y: v.y * frameScale + offsetY });
      const framedVerts = face.rawVerts.map(frame);

      this.ctx.beginPath();
      this.ctx.moveTo(framedVerts[0].x, framedVerts[0].y);
      for (let i = 1; i < framedVerts.length; i++) this.ctx.lineTo(framedVerts[i].x, framedVerts[i].y);
      this.ctx.closePath();
      this.ctx.fillStyle = face.fillColor;
      this.ctx.fill();

      face.decorations.forEach(deco => {
        const decoVerts = deco.projVerts.map(frame);
        if (deco.type === 'polygon') {
          this.ctx.beginPath();
          this.ctx.moveTo(decoVerts[0].x, decoVerts[0].y);
          for (let i = 1; i < decoVerts.length; i++) this.ctx.lineTo(decoVerts[i].x, decoVerts[i].y);
          this.ctx.closePath();
          this.ctx.fillStyle = deco.color;
          this.ctx.fill();

          for (let i = 0; i < decoVerts.length; i++) {
            this.drawSketchyLine(decoVerts[i], decoVerts[(i + 1) % decoVerts.length], 'rgba(0,0,0,0.5)', 1);
          }
        } else if (deco.type === 'line') {
          this.drawSketchyLine(decoVerts[0], decoVerts[1], deco.color, 2);
        }
      });

      for (let i = 0; i < framedVerts.length; i++) {
        this.drawSketchyLine(framedVerts[i], framedVerts[(i + 1) % framedVerts.length], face.strokeColor, 2);
      }
    });
  }

  drawSketchyLine(p1, p2, color, thicknessMod = 1) {
    const dpr = window.devicePixelRatio || 1;
    const cssW = this.canvas.width / dpr;

    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = Math.max(1.2, cssW * 0.0025) * thicknessMod;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';

    const passes = 2;
    for (let pass = 0; pass < passes; pass++) {
      this.ctx.beginPath();

      let dx = p2.x - p1.x;
      let dy = p2.y - p1.y;
      let len = Math.hypot(dx, dy);
      if (len < 0.1) continue;

      let dirX = dx / len;
      let dirY = dy / len;

      let overshoot = Math3D.rand(1, 3);
      let startX = p1.x - dirX * overshoot + Math3D.rand(-0.8, 0.8);
      let startY = p1.y - dirY * overshoot + Math3D.rand(-0.8, 0.8);
      this.ctx.moveTo(startX, startY);

      let segmentLength = Math3D.rand(6, 12);
      let numSegments = Math.max(1, Math.floor(len / segmentLength));

      for (let i = 1; i <= numSegments; i++) {
        let t = i / numSegments;
        let jitter = (i === numSegments) ? 0 : Math3D.rand(-1, 1);

        let mx = p1.x + dx * t - dirY * jitter;
        let my = p1.y + dy * t + dirX * jitter;

        this.ctx.lineTo(mx, my);
      }

      this.ctx.globalAlpha = pass === 0 ? 0.8 : 0.4;
      this.ctx.stroke();
    }
    this.ctx.globalAlpha = 1.0;
  }
}

window.initBoxArt = function(canvasId = 'artCanvas') {
  return new Renderer(canvasId);
};
