// Mesa de dados 3D: three.js (desenho em WebGL, luz e sombras) e cannon-es
// (física: gravidade, quique, atrito e dados batendo um no outro). O
// resultado é a face que ficou para cima de verdade (no D4, a ponta de cima).
// A mesma mesa roda no site e no app (assets/dice, numa WebView).

import * as THREE from 'three'
import * as CANNON from 'cannon-es'
import { DICE, dieShape, vec } from './geometry'
import { playClack, unlockSound } from './sound'

const SIZE = 1 // raio dos dados na mesa
const UP = new THREE.Vector3(0, 1, 0)

function shade(hex, amount) {
  const c = new THREE.Color(hex)
  const hsl = {}
  c.getHSL(hsl)
  c.setHSL(hsl.h, hsl.s, Math.min(1, Math.max(0, hsl.l + amount)))
  return `#${c.getHexString()}`
}

/** A textura de uma face: a cor do dado e o número (no D4, os 3 das pontas). */
function faceTexture(color, draw) {
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = 256
  const g = canvas.getContext('2d')
  const grad = g.createRadialGradient(110, 100, 20, 128, 128, 190)
  grad.addColorStop(0, shade(color, 0.08))
  grad.addColorStop(1, shade(color, -0.06))
  g.fillStyle = grad
  g.fillRect(0, 0, 256, 256)
  g.textAlign = 'center'
  g.textBaseline = 'middle'
  g.fillStyle = '#ffffff'
  g.strokeStyle = 'rgba(0,0,0,0.45)'
  g.lineJoin = 'round'
  draw(g)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.anisotropy = 4
  return texture
}

function writeNumber(g, text, x, y, px, angle = 0) {
  g.save()
  g.translate(x, y)
  g.rotate(angle)
  g.font = `900 ${px}px Roboto, Arial, sans-serif`
  g.lineWidth = px * 0.12
  g.strokeText(text, 0, px * 0.04)
  g.fillText(text, 0, px * 0.04)
  g.restore()
}

/** A malha do dado: cada face com a textura do número, no plano da face. */
function buildMesh(shape, color) {
  const positions = []
  const uvs = []
  const geometry = new THREE.BufferGeometry()
  const materials = []
  const v = shape.vertices.map((p) => vec.mul(p, SIZE))

  shape.faces.forEach((f, index) => {
    const center = vec.mul(f.center, SIZE)
    const right = vec.cross(f.up, f.normal) // como no app: direita = cima × normal
    const pts = f.corners.map((m) => v[m])
    const local = pts.map((p) => {
      const d = vec.sub(p, center)
      return [vec.dot(d, right), vec.dot(d, f.up)]
    })
    const R = Math.max(...local.map(([x, y]) => Math.hypot(x, y)))
    const uvOf = ([x, y]) => [0.5 + (x / R) * 0.49, 0.5 + (y / R) * 0.49]
    // Raio do círculo dentro da face, para o tamanho do número.
    let inr = Infinity
    for (let k = 0; k < local.length; k++) {
      const [ax, ay] = local[k]
      const [bx, by] = local[(k + 1) % local.length]
      inr = Math.min(inr, Math.abs(ax * by - ay * bx) / Math.hypot(bx - ax, by - ay))
    }

    const start = positions.length / 3
    for (let k = 1; k < pts.length - 1; k++) {
      for (const idx of [0, k, k + 1]) {
        positions.push(...pts[idx])
        uvs.push(...uvOf(local[idx]))
      }
    }
    geometry.addGroup(start, positions.length / 3 - start, index)

    const texture = faceTexture(color, (g) => {
      const scale = 128 / R
      if (shape.vertexValues) {
        // D4: cada ponta mostra o número dela, com o "pé" virado para o centro.
        f.corners.forEach((m, k) => {
          const [x, y] = local[k]
          const cx = 128 + x * scale * 0.98 * 0.55
          const cy = 128 - y * scale * 0.98 * 0.55
          writeNumber(g, String(shape.vertexValues[m]), cx, cy, inr * scale * 0.62, Math.atan2(x, y))
        })
      } else {
        const digits = f.label.replace('.', '').length
        const px = inr * scale * (digits === 1 ? 1.05 : digits === 2 ? 0.8 : 0.66)
        writeNumber(g, f.label, 128, 128, px)
      }
    })
    materials.push(new THREE.MeshStandardMaterial({ map: texture, roughness: 0.42, metalness: 0.05 }))
  })

  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3))
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2))
  // Sem índices, cada triângulo tem a própria normal: faces lisas, arestas marcadas.
  geometry.computeVertexNormals()

  const mesh = new THREE.Mesh(geometry, materials)
  mesh.castShadow = true
  const edges = new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 20), new THREE.LineBasicMaterial({ color: shade(color, -0.25), transparent: true, opacity: 0.6 }))
  mesh.add(edges)
  return mesh
}

/**
 * Cria a mesa dentro de [container].
 * onResult({ kind, values, total }) é chamado quando os dados param.
 */
export function createDiceTable(container, { onResult, onRollStart } = {}) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  renderer.outputColorSpace = THREE.SRGBColorSpace
  renderer.domElement.style.display = 'block'
  renderer.domElement.style.width = '100%'
  renderer.domElement.style.height = '100%'
  renderer.domElement.style.touchAction = 'none'
  container.appendChild(renderer.domElement)

  const scene = new THREE.Scene()
  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 100)
  camera.position.set(0, 10.5, 4.6)
  camera.lookAt(0, 0, 0.25)

  scene.add(new THREE.HemisphereLight(0xffffff, 0x445566, 0.9))
  const sun = new THREE.DirectionalLight(0xffffff, 1.9)
  sun.position.set(-4, 12, 6)
  sun.castShadow = true
  sun.shadow.mapSize.set(1024, 1024)
  Object.assign(sun.shadow.camera, { left: -9, right: 9, top: 9, bottom: -9, near: 1, far: 40 })
  sun.shadow.radius = 4
  scene.add(sun)

  const floor = new THREE.Mesh(new THREE.PlaneGeometry(60, 60), new THREE.ShadowMaterial({ opacity: 0.38 }))
  floor.rotation.x = -Math.PI / 2
  floor.receiveShadow = true
  scene.add(floor)

  // Física.
  const world = new CANNON.World({ gravity: new CANNON.Vec3(0, -34, 0) })
  world.allowSleep = true
  world.broadphase = new CANNON.SAPBroadphase(world)
  const tableMat = new CANNON.Material('table')
  const diceMat = new CANNON.Material('dice')
  world.addContactMaterial(new CANNON.ContactMaterial(tableMat, diceMat, { friction: 0.32, restitution: 0.34 }))
  world.addContactMaterial(new CANNON.ContactMaterial(diceMat, diceMat, { friction: 0.18, restitution: 0.45 }))

  const ground = new CANNON.Body({ mass: 0, material: tableMat, shape: new CANNON.Plane() })
  ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0)
  world.addBody(ground)

  let walls = []
  let half = { w: 3, d: 3 }
  function layout() {
    const w = Math.max(1, container.clientWidth)
    const h = Math.max(1, container.clientHeight)
    renderer.setSize(w, h, false)
    camera.aspect = w / h
    camera.updateProjectionMatrix()
    // A área da mesa que aparece na tela (para as paredes ficarem na borda).
    const dist = camera.position.length()
    const visibleH = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * dist
    half = { w: Math.max(2.4, (visibleH * camera.aspect) / 2 - 0.5), d: Math.max(2.2, visibleH / 2 - 0.6) }
    for (const b of walls) world.removeBody(b)
    walls = [
      [new CANNON.Vec3(half.w, 0, 0), [0, -Math.PI / 2, 0]],
      [new CANNON.Vec3(-half.w, 0, 0), [0, Math.PI / 2, 0]],
      [new CANNON.Vec3(0, 0, half.d), [0, Math.PI, 0]],
      [new CANNON.Vec3(0, 0, -half.d), [0, 0, 0]],
    ].map(([pos, [x, y, z]]) => {
      const b = new CANNON.Body({ mass: 0, material: tableMat, shape: new CANNON.Plane(), position: pos })
      b.quaternion.setFromEuler(x, y, z)
      world.addBody(b)
      return b
    })
    render()
  }

  let dice = [] // { kind, shape, mesh, body }
  let kind = 'd20'
  let rolling = false
  let settledFrames = 0
  let rollStart = 0
  let frame = 0
  let lastTime = 0

  function clear() {
    for (const d of dice) {
      scene.remove(d.mesh)
      world.removeBody(d.body)
      d.mesh.geometry.dispose()
      for (const m of d.mesh.material) {
        m.map?.dispose()
        m.dispose()
      }
    }
    dice = []
  }

  function makeDie(dieKind, color) {
    const shape = dieShape(dieKind)
    const mesh = buildMesh(shape, color)
    scene.add(mesh)
    const body = new CANNON.Body({
      mass: 1,
      material: diceMat,
      shape: new CANNON.ConvexPolyhedron({
        vertices: shape.vertices.map((p) => new CANNON.Vec3(...vec.mul(p, SIZE))),
        faces: shape.faces.map((f) => f.corners),
      }),
      linearDamping: 0.08,
      angularDamping: 0.08,
      allowSleep: true,
      sleepSpeedLimit: 0.18,
      sleepTimeLimit: 0.35,
    })
    body.userData = { die: true }
    let lastSound = 0
    body.addEventListener('collide', (e) => {
      const speed = Math.abs(e.contact.getImpactVelocityAlongNormal())
      const now = performance.now()
      if (speed < 0.9 || now - lastSound < 35) return
      lastSound = now
      playClack(speed / 16, e.body?.userData?.die ? 'dice' : 'table')
    })
    world.addBody(body)
    return { kind: dieKind, shape, mesh, body }
  }

  function diceFor(k) {
    const info = DICE.find((d) => d.kind === k) ?? DICE[5]
    if (k === 'd100') return [makeDie('d100', info.color), makeDie('d10', '#f4511e')]
    return [makeDie(k, info.color)]
  }

  /** Deixa o dado parado no centro com o maior número para cima (antes de rolar). */
  function show(k) {
    kind = k
    rolling = false
    clear()
    dice = diceFor(k)
    dice.forEach((d, i) => {
      const top = d.shape.vertexValues ? d.shape.faces[0] : d.shape.faces.reduce((a, b) => (b.value > a.value ? b : a))
      const n = new THREE.Vector3(...top.normal)
      const q1 = new THREE.Quaternion().setFromUnitVectors(n, d.shape.vertexValues ? UP.clone().negate() : UP)
      const up = new THREE.Vector3(...top.up).applyQuaternion(q1)
      up.y = 0
      const q2 = up.lengthSq() > 1e-6 ? new THREE.Quaternion().setFromUnitVectors(up.normalize(), new THREE.Vector3(0, 0, -1)) : new THREE.Quaternion()
      const q = q2.multiply(q1)
      // Leve giro para ver o dado em 3D.
      q.premultiply(new THREE.Quaternion().setFromAxisAngle(UP, -0.35))
      const rest = vec.dot(top.center, top.normal) * SIZE
      const x = dice.length > 1 ? (i === 0 ? -1.3 : 1.3) : 0
      d.body.position.set(x, rest + 0.01, 0)
      d.body.quaternion.set(q.x, q.y, q.z, q.w)
      d.body.velocity.setZero()
      d.body.angularVelocity.setZero()
      d.body.sleep()
    })
    sync()
    render()
  }

  /** Joga os dados na mesa. */
  function roll(k = kind) {
    unlockSound()
    if (k !== kind || !dice.length) show(k)
    kind = k
    dice.forEach((d, i) => {
      const b = d.body
      b.wakeUp()
      const spread = dice.length > 1 ? (i === 0 ? -1 : 1) : 0
      b.position.set(spread * 1.2 + (Math.random() - 0.5) * 1.5, 2.2 + Math.random() * 1.2, half.d - 0.8)
      const q = new CANNON.Quaternion()
      q.setFromEuler(Math.random() * 6.28, Math.random() * 6.28, Math.random() * 6.28)
      b.quaternion.copy(q)
      b.velocity.set((Math.random() - 0.5) * 7 - spread * 1.5, 2 + Math.random() * 2, -(11 + Math.random() * 6))
      b.angularVelocity.set((Math.random() - 0.5) * 40, (Math.random() - 0.5) * 40, (Math.random() - 0.5) * 40)
    })
    rolling = true
    settledFrames = 0
    rollStart = performance.now()
    onRollStart?.()
    start()
  }

  function topValue(d) {
    const q = d.mesh.quaternion
    if (d.shape.vertexValues) {
      // D4: a ponta mais alta.
      let best = 0
      let bestY = -Infinity
      d.shape.vertices.forEach((p, i) => {
        const y = new THREE.Vector3(...p).applyQuaternion(q).y
        if (y > bestY) {
          bestY = y
          best = i
        }
      })
      return { value: d.shape.vertexValues[best], flat: true }
    }
    let best = null
    let bestY = -Infinity
    for (const f of d.shape.faces) {
      const y = new THREE.Vector3(...f.normal).applyQuaternion(q).y
      if (y > bestY) {
        bestY = y
        best = f
      }
    }
    return { value: best.value, flat: bestY > 0.88 }
  }

  function finish() {
    rolling = false
    const results = dice.map(topValue)
    // Parou torto (apoiado na parede ou em outro dado)? Um empurrãozinho.
    if (results.some((r) => !r.flat) && performance.now() - rollStart < 9000) {
      dice.forEach((d, i) => {
        if (results[i].flat) return
        d.body.wakeUp()
        d.body.velocity.set((Math.random() - 0.5) * 3, 4, (Math.random() - 0.5) * 3)
        d.body.angularVelocity.set((Math.random() - 0.5) * 12, (Math.random() - 0.5) * 12, (Math.random() - 0.5) * 12)
      })
      rolling = true
      settledFrames = 0
      return
    }
    const values = results.map((r) => r.value)
    let total = values.reduce((a, b) => a + b, 0)
    if (kind === 'd100' && total === 0) total = 100 // 00 + 0
    onResult?.({ kind, values, total })
  }

  function sync() {
    for (const d of dice) {
      d.mesh.position.copy(d.body.position)
      d.mesh.quaternion.copy(d.body.quaternion)
    }
  }

  function render() {
    renderer.render(scene, camera)
  }

  function tick(time) {
    frame = 0
    const dt = Math.min(0.05, (time - (lastTime || time)) / 1000)
    lastTime = time
    world.step(1 / 120, dt, 8)
    sync()
    render()
    if (rolling) {
      const still = dice.every((d) => d.body.sleepState === CANNON.Body.SLEEPING || (d.body.velocity.length() < 0.08 && d.body.angularVelocity.length() < 0.12))
      settledFrames = still ? settledFrames + 1 : 0
      if (settledFrames > 12 || performance.now() - rollStart > 12000) finish()
    }
    if (rolling) frame = requestAnimationFrame(tick)
    else lastTime = 0
  }

  function start() {
    if (!frame) frame = requestAnimationFrame(tick)
  }

  const observer = new ResizeObserver(layout)
  observer.observe(container)
  layout()
  show(kind)

  return {
    roll,
    show,
    get kind() {
      return kind
    },
    get rolling() {
      return rolling
    },
    dispose() {
      cancelAnimationFrame(frame)
      observer.disconnect()
      clear()
      renderer.dispose()
      renderer.domElement.remove()
    },
  }
}
