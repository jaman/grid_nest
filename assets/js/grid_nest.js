const BROWSER_HASH_KEY = "grid_nest:browser_hash";

const noopAdapter = {
  loadBrowserHash() {
    return null;
  },
  saveBrowserHash(_hash) {},
  loadLayout(_key) {
    return null;
  },
  saveLayout(_key, _layout) {},
  clearLayout(_key) {}
};

const localStorageAdapter = {
  loadBrowserHash() {
    try {
      return window.localStorage.getItem(BROWSER_HASH_KEY);
    } catch (_error) {
      return null;
    }
  },
  saveBrowserHash(hash) {
    try {
      window.localStorage.setItem(BROWSER_HASH_KEY, hash);
    } catch (_error) {}
  },
  loadLayout(key) {
    try {
      const raw = window.localStorage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    } catch (_error) {
      return null;
    }
  },
  saveLayout(key, layout) {
    try {
      window.localStorage.setItem(key, JSON.stringify(layout));
    } catch (_error) {}
  },
  clearLayout(key) {
    try {
      window.localStorage.removeItem(key);
    } catch (_error) {}
  }
};

function indexedDbAdapter() {
  return localStorageAdapter;
}

function pickAdapter(name) {
  switch (name) {
    case "local_storage":
      return localStorageAdapter;
    case "indexed_db":
      return indexedDbAdapter();
    case "none":
    case "":
    case null:
    case undefined:
      return noopAdapter;
    default:
      return noopAdapter;
  }
}

function generateBrowserHash() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return "bh-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function ensureBrowserHash(adapter) {
  const existing = adapter.loadBrowserHash();
  if (existing) return existing;
  const fresh = generateBrowserHash();
  adapter.saveBrowserHash(fresh);
  return fresh;
}

function layoutStorageKey(boardId, pageKey, browserHash) {
  return `grid_nest:layout:${boardId}:${pageKey}:${browserHash || "__none__"}`;
}

function clearLocalLayouts() {
  try {
    const keys = [];
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (key && key.startsWith("grid_nest:")) keys.push(key);
    }
    keys.forEach((key) => window.localStorage.removeItem(key));
  } catch (_error) {}
}

function measureGrid(gridEl) {
  const rect = gridEl.getBoundingClientRect();
  const styles = getComputedStyle(gridEl);
  const cols = Number(styles.getPropertyValue("--grid-cols")) || 12;
  const rowHeight = Number(styles.getPropertyValue("--grid-row-height")) || 60;
  const gap = Number(styles.getPropertyValue("--grid-gap")) || 8;
  const cellWidth = (rect.width - gap * (cols - 1)) / cols;
  return { rect, cols, rowHeight, gap, cellWidth };
}

function snapMove({ origin, pointer, metrics }) {
  const dx = pointer.x - origin.x;
  const dy = pointer.y - origin.y;
  const unitWidth = metrics.cellWidth + metrics.gap;
  const unitHeight = metrics.rowHeight + metrics.gap;
  const snappedDx = Math.round(dx / unitWidth);
  const snappedDy = Math.round(dy / unitHeight);
  const x = clampNonNeg(origin.gridX + snappedDx);
  const maxX = metrics.cols - origin.gridW;
  return {
    x: Math.min(x, Math.max(0, maxX)),
    y: clampNonNeg(origin.gridY + snappedDy)
  };
}

function snapResize({ origin, pointer, metrics }) {
  const dx = pointer.x - origin.x;
  const dy = pointer.y - origin.y;
  const unitWidth = metrics.cellWidth + metrics.gap;
  const unitHeight = metrics.rowHeight + metrics.gap;
  const snappedDw = Math.round(dx / unitWidth);
  const snappedDh = Math.round(dy / unitHeight);
  const w = Math.max(1, origin.gridW + snappedDw);
  const maxW = metrics.cols - origin.gridX;
  return {
    w: Math.min(w, Math.max(1, maxW)),
    h: Math.max(1, origin.gridH + snappedDh)
  };
}

function clampNonNeg(value) {
  return value < 0 ? 0 : value;
}

function readTileCoords(tileEl) {
  return {
    gridX: Number(tileEl.dataset.x || "0"),
    gridY: Number(tileEl.dataset.y || "0"),
    gridW: Number(tileEl.dataset.w || "1"),
    gridH: Number(tileEl.dataset.h || "1")
  };
}

function canStartDrag(target, tile) {
  const hasDesignatedHandle = !!tile.querySelector("[data-grid-nest-drag-handle]");
  if (!hasDesignatedHandle) return true;

  const handle = target.closest("[data-grid-nest-drag-handle]");
  return !!handle && tile.contains(handle);
}

function createGhost(coords, mode) {
  const ghost = document.createElement("div");
  ghost.className = "grid-nest-drop-ghost";
  ghost.style.gridColumn = `${coords.gridX + 1} / span ${coords.gridW}`;
  ghost.style.gridRow = `${coords.gridY + 1} / span ${coords.gridH}`;
  return ghost;
}

function updateGhost(ghost, x, y, w, h) {
  if (!ghost) return;
  ghost.style.gridColumn = `${x + 1} / span ${w}`;
  ghost.style.gridRow = `${y + 1} / span ${h}`;
}

const GridNestBoard = {
  mounted() {
    this.clientStorage = this.el.dataset.clientStorage || "none";
    this.pageKey = this.el.dataset.pageKey || "";
    this.adapter = pickAdapter(this.clientStorage);

    this.browserHash = this.adapter.loadBrowserHash() || "";

    this.handleRequestHydrate = (payload) => {
      if (payload && payload.id && payload.id !== this.el.id) return;
      const storageKey = this.currentStorageKey();
      const layout = storageKey ? this.adapter.loadLayout(storageKey) : null;
      this.pushEventTo(this.el, "grid_nest:hydrate", {
        layout: layout,
        browser_hash: this.browserHash
      });
    };

    this.handleLayoutSaved = (payload) => {
      if (payload && payload.id && payload.id !== this.el.id) return;
      if (!payload || !Array.isArray(payload.layout)) return;
      if (this.clientStorage === "none") return;
      if (!this.browserHash) {
        this.browserHash = ensureBrowserHash(this.adapter);
      }
      const storageKey = this.currentStorageKey();
      if (storageKey) this.adapter.saveLayout(storageKey, payload.layout);
    };

    this.handleEvent("grid_nest:request_hydrate", this.handleRequestHydrate);
    this.handleEvent("grid_nest:layout_saved", this.handleLayoutSaved);

    this.onPointerDown = this.onPointerDown.bind(this);
    this.onPointerMove = this.onPointerMove.bind(this);
    this.onPointerUp = this.onPointerUp.bind(this);
    this.el.addEventListener("pointerdown", this.onPointerDown);
  },

  currentStorageKey() {
    return this.browserHash
      ? layoutStorageKey(this.el.id, this.pageKey, this.browserHash)
      : null;
  },

  beforeUpdate() {
    if (!this.drag || !this.drag.tileEl) return;
    const tileEl = this.drag.tileEl;
    this.dragSnapshot = {
      tileId: this.drag.tileId,
      transform: tileEl.style.transform,
      width: tileEl.style.width,
      height: tileEl.style.height
    };
  },

  updated() {
    const snapshot = this.dragSnapshot;
    if (!snapshot || !this.drag) return;

    const tileEl = this.el.querySelector(
      `[data-grid-nest-tile][data-id="${CSS.escape(snapshot.tileId)}"]`
    );
    if (tileEl) {
      tileEl.classList.add("grid-nest-tile--dragging");
      tileEl.style.transform = snapshot.transform;
      tileEl.style.width = snapshot.width;
      tileEl.style.height = snapshot.height;
      this.drag.tileEl = tileEl;
    }
    this.dragSnapshot = null;
  },

  destroyed() {
    this.el.removeEventListener("pointerdown", this.onPointerDown);
    window.removeEventListener("pointermove", this.onPointerMove);
    window.removeEventListener("pointerup", this.onPointerUp);
    if (this.ghost) {
      this.ghost.remove();
      this.ghost = null;
    }
  },

  onPointerDown(event) {
    const tile = event.target.closest("[data-grid-nest-tile]");
    if (!tile || !this.el.contains(tile)) return;

    const resizeHandle = event.target.closest("[data-grid-nest-resize]");
    const mode = resizeHandle ? "resize" : "drag";

    if (mode === "resize") {
      if (tile.dataset.resizable === "false") return;
    } else {
      if (tile.dataset.movable === "false") return;
      if (!canStartDrag(event.target, tile)) return;
    }

    const tileRect = tile.getBoundingClientRect();
    const coords = readTileCoords(tile);

    this.drag = {
      mode,
      tileId: tile.dataset.id,
      tileEl: tile,
      origin: {
        x: event.clientX,
        y: event.clientY,
        tileLeft: tileRect.left,
        tileTop: tileRect.top,
        tileWidth: tileRect.width,
        tileHeight: tileRect.height,
        ...coords
      }
    };

    tile.classList.add("grid-nest-tile--dragging");
    this.ghost = createGhost(coords, mode);
    this.el.appendChild(this.ghost);
    window.addEventListener("pointermove", this.onPointerMove);
    window.addEventListener("pointerup", this.onPointerUp);
    event.preventDefault();
  },

  onPointerMove(event) {
    if (!this.drag) return;
    const dx = event.clientX - this.drag.origin.x;
    const dy = event.clientY - this.drag.origin.y;
    const metrics = measureGrid(this.el);
    const pointer = { x: event.clientX, y: event.clientY };

    if (this.drag.mode === "drag") {
      this.drag.tileEl.style.transform = `translate(${dx}px, ${dy}px)`;
      const { x, y } = snapMove({ origin: this.drag.origin, pointer, metrics });
      updateGhost(this.ghost, x, y, this.drag.origin.gridW, this.drag.origin.gridH);
    } else {
      this.drag.tileEl.style.width = `${Math.max(16, this.drag.origin.tileWidth + dx)}px`;
      this.drag.tileEl.style.height = `${Math.max(16, this.drag.origin.tileHeight + dy)}px`;
      const { w, h } = snapResize({ origin: this.drag.origin, pointer, metrics });
      updateGhost(this.ghost, this.drag.origin.gridX, this.drag.origin.gridY, w, h);
    }
  },

  onPointerUp(event) {
    if (!this.drag) return;

    const metrics = measureGrid(this.el);
    const pointer = { x: event.clientX, y: event.clientY };
    const tileEl = this.drag.tileEl;

    if (this.ghost) {
      this.ghost.remove();
      this.ghost = null;
    }

    const finalize = () => {
      tileEl.classList.remove("grid-nest-tile--dragging");
      tileEl.style.transform = "";
      tileEl.style.width = "";
      tileEl.style.height = "";
    };

    if (this.drag.mode === "drag") {
      const { x, y } = snapMove({ origin: this.drag.origin, pointer, metrics });
      this.pushEventTo(
        this.el,
        "grid_nest:move",
        { id: this.drag.tileId, x: x, y: y },
        finalize
      );
    } else {
      const { w, h } = snapResize({ origin: this.drag.origin, pointer, metrics });
      this.pushEventTo(
        this.el,
        "grid_nest:resize",
        { id: this.drag.tileId, w: w, h: h },
        finalize
      );
    }

    this.drag = null;

    window.removeEventListener("pointermove", this.onPointerMove);
    window.removeEventListener("pointerup", this.onPointerUp);
  }
};

export {
  GridNestBoard,
  pickAdapter,
  generateBrowserHash,
  layoutStorageKey,
  clearLocalLayouts,
  snapMove,
  snapResize
};
export default GridNestBoard;
