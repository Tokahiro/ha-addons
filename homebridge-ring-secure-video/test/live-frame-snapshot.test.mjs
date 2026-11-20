import assert from 'node:assert/strict'
import test from 'node:test'
import { useLogger } from 'ring-client-api/util'
import { CameraSource } from '../lib/camera-source.js'

useLogger({ logInfo() {}, logError() {}, logDebug() {} })

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 0xff, 0xd9])

// A CameraSource for Ring Intercom Video, whose Ring snapshot always gives 404.
function fakeSource({ preWarmed = true, hasCall = false, frame = jpeg } = {}) {
  const source = Object.create(CameraSource.prototype),
    events = []
  source.cachedSnapshotAt = 0
  source.ringCamera = {
    name: 'Front Gate',
    isOffline: false,
    snapshotsAreBlocked: false,
    hasSnapshotWithinLifetime: false,
    snapshotLifeTime: 30_000,
    hasPreWarmedCall: preWarmed === null ? undefined : () => preWarmed,
    getSnapshot: async () => {
      events.push('ring snapshot')
      throw new Error('Snapshot not available for Front Gate')
    },
  }
  source.mediaIngress = {
    hasCall,
    acquire: async (consumer) => {
      events.push(`acquire ${consumer}`)
      return {
        createTranscoder: async (options) => {
          assert.deepEqual(options.video.slice(0, 2), ['-frames:v', '1'])
          if (frame) options.stdoutCallback(frame)
          return { stop() {}, exited: Promise.resolve() }
        },
        release: () => events.push('release'),
      }
    },
  }
  return { source, events }
}

const snapshot = (source) =>
  new Promise((resolve, reject) =>
    source.handleSnapshotRequest({}, (error, image) => (error ? reject(error) : resolve(image))),
  )

test('a pre-warmed call gives the snapshot and is held for the recording', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const { source, events } = fakeSource()
  assert.deepEqual(await snapshot(source), jpeg)
  assert.deepEqual(events, ['acquire snapshot'], 'no Ring snapshot, call not released yet')
  t.mock.timers.tick(15_000)
  assert.deepEqual(events, ['acquire snapshot', 'release'])
})

test('a running call is released right after the frame', async () => {
  const { source, events } = fakeSource({ preWarmed: false, hasCall: true })
  assert.deepEqual(await snapshot(source), jpeg)
  assert.deepEqual(events, ['acquire snapshot', 'release'])
})

test('a new frame is used again for 10 s', async () => {
  const { source, events } = fakeSource({ preWarmed: false, hasCall: true })
  await snapshot(source)
  await snapshot(source)
  assert.equal(events.filter((e) => e === 'acquire snapshot').length, 1)
})

test('without a call, no call is started for a snapshot', async () => {
  const { source, events } = fakeSource({ preWarmed: false })
  await assert.rejects(snapshot(source), /No Snapshot Cached/)
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(events, ['ring snapshot'])
})

test('other cameras never take a frame', async () => {
  const { source, events } = fakeSource({ preWarmed: null, hasCall: true })
  await assert.rejects(snapshot(source), /No Snapshot Cached/)
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(events, ['ring snapshot'])
})

test('a frame that is not a JPEG falls back to Ring', async () => {
  const { source, events } = fakeSource({ preWarmed: false, hasCall: true, frame: Buffer.from('x') })
  await assert.rejects(snapshot(source), /No Snapshot Cached/)
  assert.deepEqual(events, ['acquire snapshot', 'release', 'ring snapshot'])
})
