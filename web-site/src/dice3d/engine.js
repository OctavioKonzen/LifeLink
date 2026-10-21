// Mesa de dados 3D: three.js (desenho em WebGL, luz e sombras) e cannon-es
// (física: gravidade, quique, atrito e dados batendo um no outro). O
// resultado é a face que ficou para cima de verdade (no D4, a ponta de cima).
// A mesma mesa roda no site e no app (assets/dice, numa WebView).

import * as THREE from 'three'
import * as CANNON from 'cannon-es'
import { DICE, dieShape, vec } from './geometry'
import { playClack, unlockSound } from './sound'

const UP = new THREE.Vector3(0, 1, 0)

function shade(hex, amount) {
  const c = new THREE.Color(hex)
  const hsl = {}
  c.getHSL(hsl)
  c.setHSL(hsl.h, hsl.s, Math.min(1, Math.max(0, hsl.l + amount)))
  return `#${c.getHexString()}`
}

/** A textura de uma face: a cor do dado e o número (no D4, os 3 das pontas). */
function faceTexture(color, draw, px = 256) {
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = 256
  // O D100 tem 100 faces: texturas menores (o desenho continua em 256).
  if (px !== 256) {
    canvas.width = canvas.height = px
    canvas.getContext('2d').scale(px / 256, px / 256)
  }
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
function buildMesh(shape, color, SIZE) {
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
    }, shape.sides > 20 ? 128 : 256)
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
export function createDiceTable(container, { onResult, onRollStart, dieSize, topDown = false } = {}) {
  // Raio dos dados na mesa (dieSize pode ser uma função do tamanho da mesa).
  let SIZE = 1
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
  // De cima e um pouco de frente; na mesa da tela toda, bem de cima (para o
  // dado cair exatamente em cima de cada jogador).
  if (topDown) {
    camera.position.set(0, 12, 0.001)
    camera.lookAt(0, 0, 0)
  } else {
    camera.position.set(0, 10.5, 4.6)
    camera.lookAt(0, 0, 0.25)
  }

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
  let bounds = { minX: -3, maxX: 3, minZ: -3, maxZ: 3 }
  const raycaster = new THREE.Raycaster()
  const tablePlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0)
  function layout() {
    const w = Math.max(1, container.clientWidth)
    const h = Math.max(1, container.clientHeight)
    renderer.setSize(w, h, false)
    camera.aspect = w / h
    camera.updateProjectionMatrix()
    // A área da mesa que aparece na tela: os cantos da tela projetados na
    // mesa (as paredes ficam na borda do que se vê).
    camera.updateMatrixWorld()
    const corners = [[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([x, y]) => {
      raycaster.setFromCamera(new THREE.Vector2(x, y), camera)
      const hit = new THREE.Vector3()
      raycaster.ray.intersectPlane(tablePlane, hit)
      return hit
    })
    const margin = 0.15
    bounds = {
      minX: Math.max(corners[0].x, corners[2].x) + margin,
      maxX: Math.min(corners[1].x, corners[3].x) - margin,
      minZ: Math.max(corners[2].z, corners[3].z) + margin, // longe (alto da tela)
      maxZ: Math.min(corners[0].z, corners[1].z) - margin, // perto (pé da tela)
    }
    half = { w: (bounds.maxX - bounds.minX) / 2, d: (bounds.maxZ - bounds.minZ) / 2 }
    if (typeof dieSize === 'function') SIZE = dieSize(half)
    else if (dieSize) SIZE = dieSize
    for (const b of walls) world.removeBody(b)
    walls = [
      [new CANNON.Vec3(bounds.maxX, 0, 0), [0, -Math.PI / 2, 0]],
      [new CANNON.Vec3(bounds.minX, 0, 0), [0, Math.PI / 2, 0]],
      [new CANNON.Vec3(0, 0, bounds.maxZ), [0, Math.PI, 0]],
      [new CANNON.Vec3(0, 0, bounds.minZ), [0, 0, 0]],
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
  let rollStart = 0
  let frame = 0
  let lastTime = 0

  function resetStill() {
    for (const d of dice) d.stillMs = 0
  }

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
    const mesh = buildMesh(shape, color, SIZE)
    scene.add(mesh)
    const body = new CANNON.Body({
      mass: 1,
      material: diceMat,
      shape: new CANNON.ConvexPolyhedron({
        vertices: shape.vertices.map((p) => new CANNON.Vec3(...vec.mul(p, SIZE))),
        faces: shape.faces.map((f) => f.corners),
      }),
      // O D100 é quase uma bola: mais freio para não rolar para sempre.
      linearDamping: dieKind === 'd100' ? 0.25 : 0.08,
      angularDamping: dieKind === 'd100' ? 0.45 : 0.08,
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
      d.body.position.set(x, rest + 0.01, (bounds.minZ + bounds.maxZ) / 2)
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
    if (k !== kind || dice.length !== 1) show(k)
    kind = k
    dice.forEach((d, i) => {
      const b = d.body
      b.wakeUp()
      const spread = dice.length > 1 ? (i === 0 ? -1 : 1) : 0
      b.position.set(spread * 1.2 + (Math.random() - 0.5) * 1.5, 2.2 + Math.random() * 1.2, bounds.maxZ - 0.8)
      const q = new CANNON.Quaternion()
      q.setFromEuler(Math.random() * 6.28, Math.random() * 6.28, Math.random() * 6.28)
      b.quaternion.copy(q)
      b.velocity.set((Math.random() - 0.5) * 7 - spread * 1.5, 2 + Math.random() * 2, -(11 + Math.random() * 6))
      b.angularVelocity.set((Math.random() - 0.5) * 40, (Math.random() - 0.5) * 40, (Math.random() - 0.5) * 40)
    })
    rolling = true
    resetStill()
    rollStart = performance.now()
    onRollStart?.()
    start()
  }

  /** O ponto da mesa embaixo de (x, y) da tela, de 0 a 1. */
  function tablePoint(x, y) {
    raycaster.setFromCamera(new THREE.Vector2(x * 2 - 1, -(y * 2 - 1)), camera)
    const hit = new THREE.Vector3()
    raycaster.ray.intersectPlane(tablePlane, hit)
    hit.x = Math.max(bounds.minX + SIZE, Math.min(bounds.maxX - SIZE, hit.x))
    hit.z = Math.max(bounds.minZ + SIZE, Math.min(bounds.maxZ - SIZE, hit.z))
    return hit
  }

  /**
   * Joga um dado em cima de cada ponto: items = [{ kind, color, x, y }].
   * O resultado vem em onResult({ kind: 'many', values }) na mesma ordem.
   */
  function rollAt(items) {
    unlockSound()
    rolling = false
    clear()
    kind = 'many'
    dice = items.map((it) => makeDie(it.kind ?? 'd20', it.color ?? DICE.find((d) => d.kind === (it.kind ?? 'd20')).color))
    dice.forEach((d, i) => {
      const target = tablePoint(items[i].x, items[i].y)
      d.target = target
      const b = d.body
      b.wakeUp()
      // Cai de cima do ponto, girando, e quica um pouco em volta dele.
      b.position.set(target.x + (Math.random() - 0.5) * SIZE, 2.4 + Math.random() * 1.2, target.z + (Math.random() - 0.5) * SIZE)
      const q = new CANNON.Quaternion()
      q.setFromEuler(Math.random() * 6.28, Math.random() * 6.28, Math.random() * 6.28)
      b.quaternion.copy(q)
      b.velocity.set((Math.random() - 0.5) * 1.5, -3, (Math.random() - 0.5) * 1.5)
      b.angularVelocity.set((Math.random() - 0.5) * 36, (Math.random() - 0.5) * 36, (Math.random() - 0.5) * 36)
    })
    rolling = true
    resetStill()
    rollStart = performance.now()
    onRollStart?.()
    start()
  }

  /** Onde cada dado parou, de 0 a 1 na tela (para mostrar o número em cima). */
  function screenPositions() {
    return dice.map((d) => {
      const p = d.mesh.position.clone().project(camera)
      return { x: (p.x + 1) / 2, y: (1 - p.y) / 2 }
    })
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
    // No "Quem começa" (vários dados perto das bordas) vale a face mais para
    // cima mesmo inclinado: empurrar ali só fazia o dado bater na parede de novo.
    if (kind !== 'many' && results.some((r) => !r.flat) && performance.now() - rollStart < 5500) {
      dice.forEach((d, i) => {
        if (results[i].flat) return
        d.body.wakeUp()
        d.body.velocity.set((Math.random() - 0.5) * 3, 4, (Math.random() - 0.5) * 3)
        d.body.angularVelocity.set((Math.random() - 0.5) * 12, (Math.random() - 0.5) * 12, (Math.random() - 0.5) * 12)
      })
      rolling = true
      resetStill()
      return
    }
    const values = results.map((r) => r.value)
    if (kind === 'many') {
      onResult?.({ kind, values, total: values.reduce((a, b) => a + b, 0), positions: screenPositions() })
      return
    }
    const total = values.reduce((a, b) => a + b, 0)
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
    // "Quem começa": cada dado é puxado de leve para o seu jogador (quica e
    // rola de verdade, mas termina em cima do quadro dele).
    // Só no começo e só enquanto está longe: perto do jogador o dado fica
    // livre para parar (senão a força o mantinha se mexendo e o resultado
    // demorava).
    const pulling = performance.now() - rollStart < 2500
    for (const d of dice) {
      if (!pulling || !d.target || d.body.sleepState === CANNON.Body.SLEEPING) continue
      const b = d.body
      if (Math.hypot(d.target.x - b.position.x, d.target.z - b.position.z) < SIZE * 0.7) continue
      b.applyForce(new CANNON.Vec3((d.target.x - b.position.x) * 22 - b.velocity.x * 3, 0, (d.target.z - b.position.z) * 22 - b.velocity.z * 3))
    }
    world.step(1 / 120, dt, 8)
    sync()
    render()
    if (rolling) {
      // Parado no chão, o dado ainda treme um pouco: cada um conta o próprio
      // tempo parado (tremer não zera; só zera se voltar a rolar de verdade).
      for (const d of dice) {
        const v = d.body.velocity.length()
        const w = d.body.angularVelocity.length()
        if (d.body.sleepState === CANNON.Body.SLEEPING || (v < 0.15 && w < 0.4)) d.stillMs = (d.stillMs || 0) + dt * 1000
        else if (v > 0.6 || w > 1.5) d.stillMs = 0
      }
      if (dice.every((d) => d.stillMs > 350) || performance.now() - rollStart > 7000) finish()
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
    rollAt,
    clear() {
      rolling = false
      clear()
      render()
    },
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
