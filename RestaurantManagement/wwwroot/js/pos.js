// Shared helpers for the order / kitchen / waiter screens.
window.Pos = (function () {
    var audioCtx = null;

    function token() {
        var el = document.querySelector('input[name="__RequestVerificationToken"]');
        return el ? el.value : '';
    }

    function postForm(url, data) {
        var body = new URLSearchParams(data || {});
        body.append('__RequestVerificationToken', token());
        return fetch(url, { method: 'POST', body: body, headers: { 'X-Requested-With': 'fetch' } })
            .then(function (r) { return r.json(); });
    }

    function postJson(url, obj) {
        return fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'RequestVerificationToken': token() },
            body: JSON.stringify(obj)
        }).then(function (r) { return r.json(); });
    }

    // Browsers only allow sound after a click, so the "Enable alerts" button calls this.
    function enableAlerts(btn) {
        try { audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)(); audioCtx.resume(); } catch (e) { }
        if (window.Notification && Notification.permission === 'default') Notification.requestPermission();
        beep();
        if (btn) { btn.classList.remove('btn-outline-warning'); btn.classList.add('btn-success'); btn.innerHTML = '<i class="bi bi-bell-fill"></i> Alerts on'; }
    }

    function beep() {
        if (!audioCtx) return;
        [0, 0.22].forEach(function (t) {
            var o = audioCtx.createOscillator(), g = audioCtx.createGain();
            o.type = 'sine'; o.frequency.value = 880;
            g.gain.setValueAtTime(0.25, audioCtx.currentTime + t);
            g.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + t + 0.18);
            o.connect(g); g.connect(audioCtx.destination);
            o.start(audioCtx.currentTime + t); o.stop(audioCtx.currentTime + t + 0.2);
        });
    }

    function notify(title, text) {
        if (window.Notification && Notification.permission === 'granted') {
            try { new Notification(title, { body: text }); } catch (e) { }
        }
    }

    // Reloads a server-rendered partial every few seconds; alerts when new data-ids appear.
    function poll(opts) {
        var box = document.querySelector(opts.container);
        var known = null;
        function tick() {
            fetch(opts.url(), { headers: { 'X-Requested-With': 'fetch' } })
                .then(function (r) { if (r.redirected) { location.reload(); return null; } return r.text(); })
                .then(function (html) {
                    if (html === null) return;
                    box.innerHTML = html;
                    var m = box.querySelector('[data-ids]');
                    var ids = m && m.dataset.ids ? m.dataset.ids.split(',') : [];
                    if (known !== null) {
                        var fresh = ids.filter(function (x) { return known.indexOf(x) < 0; });
                        if (fresh.length) {
                            beep();
                            notify(opts.alertTitle, fresh.length + ' ' + opts.alertText);
                            box.classList.add('flash'); setTimeout(function () { box.classList.remove('flash'); }, 1200);
                        }
                    }
                    known = ids;
                })
                .catch(function () { });
        }
        tick();
        setInterval(tick, opts.interval || 5000);
        return tick;
    }

    // <button data-post="/Kitchen/SetStatus" data-params='{"id":3,"status":"Ready"}'>
    function wirePostButtons(refresh) {
        document.addEventListener('click', function (ev) {
            var b = ev.target.closest('[data-post]');
            if (!b) return;
            ev.preventDefault();
            b.disabled = true;
            postForm(b.dataset.post, JSON.parse(b.dataset.params || '{}')).then(function () { refresh(); });
        });
    }

    function money(n) { return '\u20B9' + Number(n).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

    return { token: token, postForm: postForm, postJson: postJson, enableAlerts: enableAlerts, poll: poll, wirePostButtons: wirePostButtons, money: money };
})();
