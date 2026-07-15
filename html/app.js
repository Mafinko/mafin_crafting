let state = {
  recipes: [],
  selected: null,
  crafting: false,
  locale: {},
  bench: {},
  ui: {},
  playerXP: 0,
  xpEnabled: false,
  showXP: false,
  progressAnim: null,
  craftTimer: null,
  filter: 'all',
  query: '',
  sort: 'available',
};

async function post(endpoint, data = {}) {
  try {
    const resourceName =
      (typeof GetParentResourceName === 'function' && GetParentResourceName()) ||
      'mafin_crafting';
    const response = await fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return await response.json();
  } catch (err) {
    console.error(`NUI Fetch Error (${endpoint}):`, err);
  }
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  switch (d.action) {
    case 'open':
      window.openUI(d.bench, d.recipes, d.locale, d.ui, d.playerXP, d.xpEnabled, d.showXP);
      break;
    case 'close':
      hideUI();
      break;
    case 'craftDone':
      craftDone();
      break;
    case 'refreshRecipes':
      refreshRecipes(d.recipes, d.playerXP);
      break;
  }
});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !document.getElementById('overlay').classList.contains('hidden')) {
    closeUI();
  }
});

document.querySelectorAll('.category-item').forEach((button) => {
  button.addEventListener('click', () => {
    if (state.crafting) return;
    state.filter = button.dataset.filter || 'all';
    document.querySelectorAll('.category-item').forEach((el) =>
      el.classList.toggle('active', el === button)
    );
    renderList(true);
  });
});

document.getElementById('search-input').addEventListener('input', (event) => {
  state.query = event.target.value.trim().toLowerCase();
  renderList(true);
});

document.getElementById('sort-select').addEventListener('change', (event) => {
  state.sort = event.target.value;
  renderList(true);
});

function openUI(bench, recipes, locale, ui, playerXP, xpEnabled, showXP) {
  clearCraftState();
  state.bench = bench || {};
  state.recipes = recipes || [];
  state.locale = locale || {};
  state.ui = ui || {};
  state.playerXP = playerXP || 0;
  state.xpEnabled = !!xpEnabled;
  state.showXP = !!showXP;
  state.selected = null;
  state.crafting = false;
  state.filter = 'all';
  state.query = '';
  state.sort = 'available';

  document.getElementById('search-input').value = '';
  document.getElementById('sort-select').value = state.sort;
  document.querySelectorAll('.category-item').forEach((el) =>
    el.classList.toggle('active', el.dataset.filter === 'all')
  );

  applyUiSettings();
  updateStaticLabels();
  updateXPBar();
  renderList(false);
  document.getElementById('overlay').classList.remove('hidden');
}

function applyUiSettings() {
  const panel = document.getElementById('panel');
  const width = Math.max(Number(state.ui.panelWidth || 1380), 1180);
  const radius = Number(state.ui.cornerRadius ?? 22);
  panel.style.setProperty('--panel-width', `${width}px`);
  panel.style.setProperty('--panel-radius', `${radius}px`);

  const title = state.ui.title || 'CRAFTING';
  document.getElementById('bench-label').textContent = title;
  document.getElementById('close-btn').classList.toggle('hidden', state.ui.showCloseButton === false);
  document.getElementById('header-meta').classList.toggle('hidden', state.ui.showHeaderMeta === false);
  document.body.classList.toggle('hide-recipe-icons', state.ui.showRecipeIcons === false);
}

function updateStaticLabels() {
  document.getElementById('header-meta-label').textContent = t('recipes_meta', 'Recipes');
  document.getElementById('detail-empty-label').textContent = t('select_recipe', 'Select recipe');
  document.getElementById('required-label').textContent = t('required', 'Materials');
  document.getElementById('result-label').textContent = t('result', 'You get');
  document.getElementById('craft-btn').textContent = t('craft_btn', 'Craft');
}

function updateHeaderMeta(visibleCount = state.recipes.length) {
  document.getElementById('header-meta-value').textContent = `${visibleCount} / ${state.recipes.length}`;
}

function updateXPBar() {
  const xpSection = document.getElementById('xp-section');
  if (!state.xpEnabled || !state.showXP) {
    xpSection.classList.add('hidden');
    return;
  }
  xpSection.classList.remove('hidden');

  const xp = state.playerXP;
  const tiers = [...new Set(
    state.recipes.map((r) => r.requiredXP || 0).filter((v) => v > xp)
  )].sort((a, b) => a - b);

  const nextTier = tiers.length > 0 ? tiers[0] : null;
  const prevTier = state.recipes.reduce((max, r) => {
    const rx = r.requiredXP || 0;
    return rx <= xp && rx > max ? rx : max;
  }, 0);

  const pct = nextTier
    ? Math.min(((xp - prevTier) / (nextTier - prevTier)) * 100, 100)
    : 100;

  document.getElementById('xp-current').textContent = `${formatNumber(xp)} XP`;
  document.getElementById('xp-next').textContent = nextTier
    ? formatLocale(t('xp_next', 'Next tier: %s XP'), nextTier)
    : t('xp_max', 'Max tier');
  document.getElementById('xp-fill').style.width = `${pct}%`;
}

function closeUI() {
  hideUI();
  post('close');
}

function hideUI() {
  state.crafting = false;
  clearCraftState();
  state.selected = null;
  document.getElementById('overlay').classList.add('hidden');
  document.getElementById('progress-bar').style.background = '';
  document.getElementById('progress-wrap').classList.add('hidden');
  document.getElementById('craft-btn').classList.remove('hidden');
}

function renderList(ensureSelection = false) {
  const container = document.getElementById('recipe-list-inner');
  if (!container) return;

  const visible = getVisibleRecipes();
  if (ensureSelection && !visible.some((entry) => entry.index === state.selected)) {
    state.selected = null;
  }

  container.innerHTML = '';
  visible.forEach(({ recipe, index }) => {
    const locked = isLocked(recipe);
    const div = document.createElement('div');
    div.className = [
      'recipe-item',
      recipe.canCraft ? '' : 'disabled',
      state.selected === index ? 'active' : '',
      locked ? 'locked' : '',
    ].filter(Boolean).join(' ');
    div.dataset.index = index;
    div.onclick = () => selectRecipe(index);

    const status = getRecipeStatus(recipe);
    const imageName = imageItemNameForRecipe(recipe);
    div.innerHTML = `
      <div class="recipe-art" data-fallback="${escapeHtml(abbrevFor(recipe.name))}">
        <img src="${inventoryImageUrl(imageName)}" alt="" draggable="false" onerror="markImageMissing(this)">
      </div>
      <div class="recipe-badge">${escapeHtml(categoryLabelFor(recipe))}</div>
      <div class="recipe-brand">${escapeHtml(imageName || 'MAFIN')}</div>
      <div class="recipe-item-name">${escapeHtml(recipe.name)}</div>
      <div class="recipe-item-status ${status.className}">${escapeHtml(status.text)}</div>
    `;
    container.appendChild(div);
  });

  updateCategoryCounts();
  updateHeaderMeta(visible.length);
  updateStats(visible);
  document.getElementById('no-results').classList.toggle('hidden', visible.length > 0);

  if (state.selected === null) {
    showEmpty(true);
  } else {
    renderDetail(state.recipes[state.selected]);
  }
}

function getVisibleRecipes() {
  const query = state.query;
  const entries = state.recipes
    .map((recipe, index) => ({ recipe, index }))
    .filter(({ recipe }) => recipeMatchesFilter(recipe, state.filter))
    .filter(({ recipe }) => {
      if (!query) return true;
      const haystack = [
        recipe.name,
        recipe.description,
        recipe.result_icon,
        categoryLabelFor(recipe),
        ...(recipe.requireditems || []).map((item) => item.name),
        ...(recipe.additems || []).map((item) => item.name),
      ].join(' ').toLowerCase();
      return haystack.includes(query);
    });

  return entries.sort((a, b) => sortRecipes(a.recipe, b.recipe));
}

function recipeMatchesFilter(recipe, filter) {
  if (filter === 'all') return true;
  if (filter === 'available') return !!recipe.canCraft && !isLocked(recipe);
  if (filter === 'locked') return isLocked(recipe);
  return categoryFor(recipe) === filter;
}

function sortRecipes(a, b) {
  if (state.sort === 'name') return String(a.name).localeCompare(String(b.name));
  if (state.sort === 'time') return (a.time || 0) - (b.time || 0);
  if (state.sort === 'xp') return (a.requiredXP || 0) - (b.requiredXP || 0);

  const aScore = (a.canCraft && !isLocked(a)) ? 0 : isLocked(a) ? 2 : 1;
  const bScore = (b.canCraft && !isLocked(b)) ? 0 : isLocked(b) ? 2 : 1;
  if (aScore !== bScore) return aScore - bScore;
  return String(a.name).localeCompare(String(b.name));
}

function updateCategoryCounts() {
  const counts = {
    all: state.recipes.length,
    available: state.recipes.filter((r) => r.canCraft && !isLocked(r)).length,
    locked: state.recipes.filter((r) => isLocked(r)).length,
    weapons: state.recipes.filter((r) => categoryFor(r) === 'weapons').length,
    medical: state.recipes.filter((r) => categoryFor(r) === 'medical').length,
    materials: state.recipes.filter((r) => categoryFor(r) === 'materials').length,
    tools: state.recipes.filter((r) => categoryFor(r) === 'tools').length,
  };

  Object.entries(counts).forEach(([key, value]) => {
    const el = document.getElementById(`count-${key}`);
    if (el) el.textContent = value;
  });
}

function updateStats(visible) {
  const available = state.recipes.filter((r) => r.canCraft && !isLocked(r)).length;
  const selected = state.selected === null ? null : state.recipes[state.selected];
  const fastest = visible.length > 0
    ? Math.min(...visible.map(({ recipe }) => recipe.time || 0).filter((time) => time > 0))
    : 0;

  document.getElementById('stat-available').textContent = available;
  document.getElementById('stat-time').textContent = selected
    ? formatDuration(selected.time || fastest)
    : fastest ? formatDuration(fastest) : '--';
  document.getElementById('stat-xp').textContent = `${formatNumber(state.playerXP)} XP`;
}

function selectRecipe(index) {
  if (state.crafting) return;
  state.selected = index;
  document.querySelectorAll('.recipe-item').forEach((el) => {
    el.classList.toggle('active', Number(el.dataset.index) === index);
  });
  renderList(false);
}

function renderDetail(r) {
  if (!r) {
    showEmpty(true);
    return;
  }
  showEmpty(false);

  const locked = isLocked(r);

  const detailImageName = imageItemNameForRecipe(r);
  const detailImageWrap = document.getElementById('detail-icon-wrap');
  const detailImage = document.getElementById('detail-image');
  detailImageWrap.dataset.fallback = abbrevFor(r.name);
  detailImage.classList.remove('image-missing');
  detailImage.src = inventoryImageUrl(detailImageName);
  detailImage.alt = '';
  document.getElementById('detail-brand').textContent = categoryLabelFor(r);
  document.getElementById('detail-name').textContent = r.name;
  document.getElementById('detail-desc').textContent = r.description || `${formatDuration(r.time || 0)} craft time`;

  const xpBadge = document.getElementById('detail-xp-badge');
  if (state.xpEnabled && (r.requiredXP || 0) > 0) {
    xpBadge.classList.remove('hidden');
    xpBadge.innerHTML = locked
      ? `<i class="fas fa-lock"></i>${escapeHtml(formatLocale(t('xp_locked', 'Requires %s XP - You have %.1f XP'), r.requiredXP, state.playerXP))}`
      : `<i class="fas fa-star"></i>${escapeHtml(formatLocale(t('xp_needed', 'Requires %s XP'), r.requiredXP))}`;
    xpBadge.className = `xp-badge ${locked ? 'badge-locked' : 'badge-ok'}`;
  } else {
    xpBadge.classList.add('hidden');
  }

  const xpRewardEl = document.getElementById('detail-xp-reward');
  if (state.xpEnabled && (r.xpReward || 0) > 0) {
    xpRewardEl.classList.remove('hidden');
    xpRewardEl.textContent = formatLocale(t('xp_reward', '+%s XP per craft'), r.xpReward);
  } else {
    xpRewardEl.classList.add('hidden');
  }

  const reqContainer = document.getElementById('detail-required');
  reqContainer.innerHTML = '';
  (r.requireditems || []).forEach((req) => {
    const row = document.createElement('div');
    row.className = `req-row ${req.ok ? 'ok' : 'err'}`;
    const noRemove = req.remove === false;
    row.innerHTML = `
      <div class="req-left">
        <span class="item-thumb" data-fallback="${escapeHtml(abbrevFor(req.name))}">
          <img src="${inventoryImageUrl(req.name)}" alt="" draggable="false" onerror="markImageMissing(this)">
        </span>
        <div class="req-dot ${req.ok ? 'ok' : 'err'}"></div>
        <span class="req-name">${escapeHtml(req.name)}</span>
        ${noRemove ? `<span class="req-tag"><i class="fas fa-lock"></i>${escapeHtml(t('not_removed', 'kept'))}</span>` : ''}
      </div>
      <div class="req-count ${req.ok ? 'ok' : 'err'}">
        <span class="have">${req.have}</span>
        <span class="sep">/</span>
        <span class="need">${req.amount}</span>
      </div>
    `;
    reqContainer.appendChild(row);
  });

  const resContainer = document.getElementById('detail-result');
  resContainer.innerHTML = '';
  (r.additems || []).forEach((add) => {
    const row = document.createElement('div');
    row.className = 'result-row';
    row.innerHTML = `
      <span class="result-left">
        <span class="item-thumb" data-fallback="${escapeHtml(abbrevFor(add.name))}">
          <img src="${inventoryImageUrl(add.name)}" alt="" draggable="false" onerror="markImageMissing(this)">
        </span>
        <span class="result-name">${escapeHtml(add.name)}</span>
      </span>
      <span class="result-amount">x${add.amount}</span>
    `;
    resContainer.appendChild(row);
  });

  const btn = document.getElementById('craft-btn');
  btn.disabled = !r.canCraft || locked;
  btn.textContent = locked ? t('locked', 'Locked') : t('craft_btn', 'Craft');
  document.getElementById('progress-wrap').classList.add('hidden');
  btn.classList.remove('hidden');
}

function doCraft() {
  if (state.crafting || state.selected === null) return;
  const r = state.recipes[state.selected];
  if (!r || !r.canCraft || isLocked(r)) return;

  state.crafting = true;
  const craftTime = r.time || 5000;

  const btn = document.getElementById('craft-btn');
  const progressWrap = document.getElementById('progress-wrap');
  const progressBar = document.getElementById('progress-bar');
  const progressLbl = document.getElementById('progress-label');

  btn.classList.add('hidden');
  progressWrap.classList.remove('hidden');
  progressLbl.textContent = t('crafting', 'Crafting...');

  const startTime = performance.now();
  function animFrame(now) {
    const pct = Math.min(((now - startTime) / craftTime) * 100, 100);
    progressBar.style.background =
      `linear-gradient(to right, var(--purple) ${pct}%, rgba(255,255,255,0.08) ${pct}%)`;
    if (pct < 100) state.progressAnim = requestAnimationFrame(animFrame);
  }
  state.progressAnim = requestAnimationFrame(animFrame);

  state.craftTimer = setTimeout(async () => {
    if (!state.crafting) return;
    state.crafting = false;
    state.craftTimer = null;
    if (state.progressAnim) cancelAnimationFrame(state.progressAnim);
    state.progressAnim = null;
    progressBar.style.background = 'linear-gradient(to right, var(--purple) 100%, rgba(255,255,255,0.08) 100%)';
    await post('craft', { recipeIndex: r.index });
    closeUI();
  }, craftTime);
}

function craftDone() {
  state.crafting = false;
  clearCraftState();
  if (document.getElementById('overlay').classList.contains('hidden')) return;
  document.getElementById('progress-bar').style.background = '';
  document.getElementById('progress-wrap').classList.add('hidden');
  document.getElementById('craft-btn').classList.remove('hidden');
}

function refreshRecipes(recipes, newXP) {
  state.recipes = recipes || [];
  if (newXP !== undefined) state.playerXP = newXP;
  if (state.selected !== null && !state.recipes[state.selected]) {
    state.selected = state.recipes.length > 0 ? 0 : null;
  }
  updateXPBar();
  renderList(true);
}

function showEmpty(show = true) {
  document.getElementById('detail').classList.toggle('hidden', show);
  document.getElementById('detail-empty').classList.toggle('hidden', !show);
  document.getElementById('detail-content').classList.toggle('hidden', show);
}

function clearCraftState() {
  if (state.progressAnim) cancelAnimationFrame(state.progressAnim);
  state.progressAnim = null;
  if (state.craftTimer) clearTimeout(state.craftTimer);
  state.craftTimer = null;
}

function isLocked(recipe) {
  return state.xpEnabled && !recipe.hasXP;
}

function getRecipeStatus(recipe) {
  if (isLocked(recipe)) {
    return {
      text: `${formatNumber(recipe.requiredXP || 0)} XP`,
      className: 'status-locked',
    };
  }
  if (recipe.canCraft) {
    return {
      text: formatDuration(recipe.time || 0),
      className: 'status-ok',
    };
  }
  return {
    text: t('missing', 'Missing materials'),
    className: 'status-err',
  };
}

function categoryFor(recipe) {
  const haystack = [
    recipe.name,
    recipe.result_icon,
    ...(recipe.additems || []).map((item) => item.name),
    ...(recipe.requireditems || []).map((item) => item.name),
  ].join(' ').toLowerCase();

  if (/weapon|gun|pistol|smg|revolver|rifle|ammo/.test(haystack)) return 'weapons';
  if (/bandage|med|firstaid|pill|armor|armour/.test(haystack)) return 'medical';
  if (/steel|scrap|iron|metal|wood|plastic|rubber|chemical/.test(haystack)) return 'materials';
  if (/tool|wrench|screw|kit|repair/.test(haystack)) return 'tools';
  return 'materials';
}

function categoryLabelFor(recipe) {
  const labels = {
    weapons: 'Weapons',
    medical: 'Medical',
    materials: 'Materials',
    tools: 'Tools',
  };
  return labels[categoryFor(recipe)] || 'Recipes';
}

function t(key, fallback) {
  return state.locale[key] || fallback || key;
}

function formatLocale(template, ...values) {
  let i = 0;
  return String(template).replace(/%(\.1f|s)/g, (match) => {
    const value = values[i++];
    return match === '%.1f' && Number.isFinite(Number(value))
      ? Number(value).toFixed(1)
      : String(value);
  });
}

function formatDuration(ms) {
  if (!ms) return '--';
  const seconds = ms / 1000;
  return seconds % 1 === 0 ? `${seconds}s` : `${seconds.toFixed(1)}s`;
}

function formatNumber(value) {
  const number = Number(value) || 0;
  return Number.isInteger(number) ? String(number) : number.toFixed(1);
}

function abbrevFor(value) {
  return String(value || 'Item')
    .split(/[\s_-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0])
    .join('')
    .toUpperCase() || 'IT';
}

function imageItemNameForRecipe(recipe) {
  return recipe?.additems?.[0]?.name || recipe?.result_icon || recipe?.name || 'item';
}

function inventoryImageUrl(itemName) {
  const normalized = String(itemName || 'item').trim().toLowerCase();
  return `nui://ox_inventory/web/images/${encodeURIComponent(normalized)}.png`;
}

function markImageMissing(img) {
  img.classList.add('image-missing');
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  }[char]));
}

// Keep the in-game interface presentation-only.
document.addEventListener('copy', (event) => event.preventDefault());
document.addEventListener('cut', (event) => event.preventDefault());
document.addEventListener('contextmenu', (event) => event.preventDefault());
document.addEventListener('dragstart', (event) => event.preventDefault());

window.openUI = openUI;
window.closeUI = closeUI;
window.doCraft = doCraft;
window.markImageMissing = markImageMissing;
