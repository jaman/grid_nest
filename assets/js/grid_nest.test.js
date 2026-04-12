import { test } from "node:test";
import assert from "node:assert/strict";
import {
  pickAdapter,
  generateBrowserHash,
  layoutStorageKey,
  snapMove,
  snapResize
} from "./grid_nest.js";

const METRICS_12 = { cols: 12, cellWidth: 50, rowHeight: 60, gap: 8 };

test("pickAdapter('none') returns a no-op adapter that never stores anything", () => {
  const adapter = pickAdapter("none");
  assert.equal(adapter.loadBrowserHash(), null);
  adapter.saveBrowserHash("irrelevant");
  assert.equal(adapter.loadBrowserHash(), null);
  assert.equal(adapter.loadLayout("k"), null);
  adapter.saveLayout("k", [{ id: "a" }]);
  assert.equal(adapter.loadLayout("k"), null);
});

test("pickAdapter falls back to the no-op adapter for unknown names", () => {
  const adapter = pickAdapter("quantum_storage");
  assert.equal(adapter.loadLayout("k"), null);
});

test("pickAdapter('local_storage') returns an adapter backed by window.localStorage", () => {
  const store = new Map();
  global.window = {
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, v),
      removeItem: (k) => store.delete(k)
    }
  };

  const adapter = pickAdapter("local_storage");
  assert.equal(adapter.loadBrowserHash(), null);
  adapter.saveBrowserHash("abc");
  assert.equal(adapter.loadBrowserHash(), "abc");

  adapter.saveLayout("layout-key", [{ id: "a", x: 0, y: 0, w: 2, h: 2 }]);
  assert.deepEqual(adapter.loadLayout("layout-key"), [
    { id: "a", x: 0, y: 0, w: 2, h: 2 }
  ]);

  adapter.clearLayout("layout-key");
  assert.equal(adapter.loadLayout("layout-key"), null);

  delete global.window;
});

test("local_storage adapter returns null on JSON parse errors", () => {
  const store = new Map([["layout-key", "not-json{"]]);
  global.window = {
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, v),
      removeItem: (k) => store.delete(k)
    }
  };

  const adapter = pickAdapter("local_storage");
  assert.equal(adapter.loadLayout("layout-key"), null);

  delete global.window;
});

test("local_storage adapter survives a throwing backing store", () => {
  global.window = {
    localStorage: {
      getItem: () => {
        throw new Error("blocked");
      },
      setItem: () => {
        throw new Error("blocked");
      },
      removeItem: () => {
        throw new Error("blocked");
      }
    }
  };

  const adapter = pickAdapter("local_storage");
  assert.equal(adapter.loadLayout("k"), null);
  adapter.saveLayout("k", []);
  adapter.clearLayout("k");
  assert.equal(adapter.loadBrowserHash(), null);
  adapter.saveBrowserHash("x");

  delete global.window;
});

test("generateBrowserHash produces a non-empty string", () => {
  const hash = generateBrowserHash();
  assert.equal(typeof hash, "string");
  assert.ok(hash.length > 0);
});

test("generateBrowserHash produces distinct values on repeated calls", () => {
  const a = generateBrowserHash();
  const b = generateBrowserHash();
  assert.notEqual(a, b);
});

test("layoutStorageKey encodes board, page and browser hash", () => {
  assert.equal(
    layoutStorageKey("dashboard", "home", "abc"),
    "grid_nest:layout:dashboard:home:abc"
  );
});

test("layoutStorageKey falls back to __none__ when browser hash is empty", () => {
  assert.equal(
    layoutStorageKey("dashboard", "home", ""),
    "grid_nest:layout:dashboard:home:__none__"
  );
});

test("snapMove returns the original grid coords when the pointer hasn't moved", () => {
  const origin = { x: 100, y: 100, gridX: 2, gridY: 3, gridW: 2, gridH: 2 };
  assert.deepEqual(
    snapMove({ origin, pointer: { x: 100, y: 100 }, metrics: METRICS_12 }),
    { x: 2, y: 3 }
  );
});

test("snapMove snaps to the next column when the pointer crosses a half-cell boundary", () => {
  const origin = { x: 0, y: 0, gridX: 0, gridY: 0, gridW: 2, gridH: 2 };
  const unitWidth = METRICS_12.cellWidth + METRICS_12.gap;
  const pointer = { x: unitWidth + 1, y: 0 };
  assert.deepEqual(snapMove({ origin, pointer, metrics: METRICS_12 }), { x: 1, y: 0 });
});

test("snapMove clamps x so the tile cannot overflow the right edge", () => {
  const origin = { x: 0, y: 0, gridX: 10, gridY: 0, gridW: 2, gridH: 2 };
  const unitWidth = METRICS_12.cellWidth + METRICS_12.gap;
  const pointer = { x: unitWidth * 10, y: 0 };
  const result = snapMove({ origin, pointer, metrics: METRICS_12 });
  assert.equal(result.x, 10);
});

test("snapMove clamps negative coordinates to zero", () => {
  const origin = { x: 500, y: 500, gridX: 1, gridY: 1, gridW: 2, gridH: 2 };
  const pointer = { x: 0, y: 0 };
  const result = snapMove({ origin, pointer, metrics: METRICS_12 });
  assert.equal(result.x, 0);
  assert.equal(result.y, 0);
});

test("snapResize grows width and height by whole-cell increments", () => {
  const origin = { x: 0, y: 0, gridX: 0, gridY: 0, gridW: 2, gridH: 2 };
  const unitWidth = METRICS_12.cellWidth + METRICS_12.gap;
  const unitHeight = METRICS_12.rowHeight + METRICS_12.gap;
  const pointer = { x: unitWidth * 3, y: unitHeight * 2 };
  assert.deepEqual(
    snapResize({ origin, pointer, metrics: METRICS_12 }),
    { w: 5, h: 4 }
  );
});

test("snapResize never returns w or h less than 1", () => {
  const origin = { x: 500, y: 500, gridX: 0, gridY: 0, gridW: 2, gridH: 2 };
  const pointer = { x: 0, y: 0 };
  const result = snapResize({ origin, pointer, metrics: METRICS_12 });
  assert.ok(result.w >= 1);
  assert.ok(result.h >= 1);
});

test("snapResize caps width at grid boundary", () => {
  const origin = { x: 0, y: 0, gridX: 8, gridY: 0, gridW: 2, gridH: 2 };
  const unitWidth = METRICS_12.cellWidth + METRICS_12.gap;
  const pointer = { x: unitWidth * 20, y: 0 };
  const result = snapResize({ origin, pointer, metrics: METRICS_12 });
  assert.equal(result.w, 4);
});
