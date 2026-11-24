(function () {
    var root = document.documentElement;
    var isDesktop = function () { return window.matchMedia('(min-width: 992px)').matches; };

    /* ---------- theme (light / dark / device) ---------- */
    function currentMode() { try { return localStorage.getItem('theme') || 'auto'; } catch (e) { return 'auto'; } }
    function applyTheme(mode) {
        var dark = mode === 'dark' || (mode === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
        root.setAttribute('data-bs-theme', dark ? 'dark' : 'light');
        var icon = document.getElementById('themeIcon');
        if (icon) icon.className = 'bi ' + (mode === 'dark' ? 'bi-moon-stars' : (mode === 'light' ? 'bi-sun' : 'bi-circle-half'));
        var meta = document.querySelector('meta[name=theme-color]');
        if (meta) meta.setAttribute('content', dark ? '#0d1411' : '#0f6b4f');
    }
    window.setTheme = function (mode) { try { localStorage.setItem('theme', mode); } catch (e) { } applyTheme(mode); };
    if (window.matchMedia) {
        var mq = window.matchMedia('(prefers-color-scheme: dark)');
        var onChange = function () { if (currentMode() === 'auto') applyTheme('auto'); };
        if (mq.addEventListener) mq.addEventListener('change', onChange); else if (mq.addListener) mq.addListener(onChange);
    }

    document.addEventListener('DOMContentLoaded', function () {
        applyTheme(currentMode());
        document.addEventListener('click', function (e) {
            var b = e.target.closest('[data-theme-set]');
            if (b) window.setTheme(b.dataset.themeSet);
        });

        /* ---------- sidebar: collapse (desktop) / slide-in (mobile) ---------- */
        var sidebar = document.getElementById('sidebar');
        var backdrop = document.getElementById('sidebarBackdrop');
        var toggle = document.getElementById('menuToggle');
        var more = document.getElementById('moreBtn');
        function closeMenu() { if (sidebar) sidebar.classList.remove('open'); if (backdrop) backdrop.classList.remove('show'); }
        function openMenu() { if (sidebar) sidebar.classList.add('open'); if (backdrop) backdrop.classList.add('show'); }
        if (toggle) toggle.addEventListener('click', function () {
            if (isDesktop()) {
                var c = root.classList.toggle('sb-collapsed');
                try { localStorage.setItem('sb', c ? 'collapsed' : 'open'); } catch (e) { }
                hideTip();
            } else if (sidebar.classList.contains('open')) closeMenu(); else openMenu();
        });
        if (more) more.addEventListener('click', openMenu);
        if (backdrop) backdrop.addEventListener('click', closeMenu);
        if (sidebar) sidebar.addEventListener('click', function (e) { if (!isDesktop() && e.target.closest('a')) closeMenu(); });

        /* tooltips for the icon-only sidebar */
        var tip = document.createElement('div'); tip.className = 'nav-tip'; document.body.appendChild(tip);
        function hideTip() { tip.classList.remove('show'); }
        document.querySelectorAll('.side-nav .nav-link').forEach(function (a) {
            var label = a.textContent.replace(/\s+/g, ' ').trim();
            a.addEventListener('mouseenter', function () {
                if (!root.classList.contains('sb-collapsed') || !isDesktop()) return;
                var r = a.getBoundingClientRect();
                tip.textContent = label; tip.style.left = (r.right + 10) + 'px'; tip.style.top = (r.top + r.height / 2 - 15) + 'px'; tip.classList.add('show');
            });
            a.addEventListener('mouseleave', hideTip);
        });
        if (sidebar) sidebar.addEventListener('scroll', hideTip);

        /* keep the active link visible in the sidebar */
        var act = document.querySelector('.side-nav .nav-link.active');
        if (act && act.scrollIntoView) act.scrollIntoView({ block: 'center' });

        /* ---------- live search on list pages ---------- */
        document.querySelectorAll('.search-box').forEach(function (box) {
            box.addEventListener('input', function () {
                var q = box.value.toLowerCase();
                document.querySelectorAll(box.dataset.table + ' tbody tr').forEach(function (tr) {
                    tr.style.display = tr.textContent.toLowerCase().indexOf(q) > -1 ? '' : 'none';
                });
            });
        });

        /* ---------- delete confirmation ---------- */
        document.querySelectorAll('form[data-confirm]').forEach(function (f) {
            f.addEventListener('submit', function (ev) {
                if (!confirm(f.dataset.confirm)) ev.preventDefault();
            });
        });

        /* ---------- auto-hide success messages ---------- */
        document.querySelectorAll('.auto-dismiss').forEach(function (a) {
            setTimeout(function () {
                if (window.bootstrap) bootstrap.Alert.getOrCreateInstance(a).close();
            }, 4000);
        });
    });
})();
