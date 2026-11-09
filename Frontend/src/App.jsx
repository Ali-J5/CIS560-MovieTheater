// App owns navigation and the active customer; child views keep their own form state.
import { useEffect, useState } from 'react';
import { api } from './api.js';
import BrowseMovies from './components/BrowseMovies.jsx';
import MyBookings from './components/MyBookings.jsx';
import AdminMoviesRooms from './components/AdminMoviesRooms.jsx';
import AdminShowtimes from './components/AdminShowtimes.jsx';
import AdminReports from './components/AdminReports.jsx';

const emptyCustomer = { firstName: '', lastName: '', email: '', phoneNumber: '', isActive: true };

export default function App() {
  // Mode and view determine which of the five content components is visible.
  const [mode, setMode] = useState('customer');
  const [view, setView] = useState('browse');
  // Keep only active customers in the top selector; the account editor also loads inactive ones.
  const [customers, setCustomers] = useState([]);
  const [customerId, setCustomerId] = useState('');
  const [accounts, setAccounts] = useState([]);
  // Account form state distinguishes a new customer from a full replacement update.
  const [accountOpen, setAccountOpen] = useState(false);
  const [editingId, setEditingId] = useState('');
  const [form, setForm] = useState(emptyCustomer);
  // Loading/busy prevent duplicate operations; messages explain API outcomes to the user.
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [reload, setReload] = useState(0);
  const customer = customers.find((c) => c.customerId === Number(customerId));

  // Load GET /customers on startup/retry; cancel obsolete requests on cleanup.
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError('');
    api.getCustomers({}, controller.signal).then((rows) => {
      setCustomers(rows);
      setCustomerId((old) => rows.some((c) => c.customerId === Number(old)) ? old : String(rows[0]?.customerId ?? ''));
    }).catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [reload]);

  // Switching modes starts at that mode's first view without changing the customer.
  function changeMode(next) {
    setMode(next);
    setView(next === 'customer' ? 'browse' : 'catalog');
    // A customer-save notice should not follow the user into an unrelated dashboard view.
    setSuccess('');
  }

  // Copy an account's editable fields; the empty option starts a fresh customer.
  function selectAccount(id, rows = accounts) {
    setEditingId(id);
    const row = rows.find((c) => c.customerId === Number(id));
    setForm(row ? { firstName: row.firstName, lastName: row.lastName, email: row.email, phoneNumber: row.phoneNumber, isActive: row.isActive } : { ...emptyCustomer });
    setSuccess('');
  }

  // Read all accounts so previously deactivated customers can be reactivated too.
  async function openAccounts() {
    setBusy(true); setError(''); setSuccess(''); setAccountOpen(true);
    try {
      const rows = await api.getCustomers({ includeInactive: true });
      setAccounts(rows);
      selectAccount(customerId, rows);
    } catch (ex) { setError(ex.message); }
    finally { setBusy(false); }
  }

  // POST creates an account; PUT replaces all editable fields, including IsActive.
  async function saveCustomer(event) {
    event.preventDefault();
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      const result = editingId ? await api.updateCustomer(editingId, form) : await api.createCustomer(form);
      saved = true;
      const [active, all] = await Promise.all([api.getCustomers(), api.getCustomers({ includeInactive: true })]);
      setCustomers(active); setAccounts(all); setEditingId(String(result.customerId));
      setCustomerId(form.isActive ? String(result.customerId) : String(active[0]?.customerId ?? ''));
      setSuccess(form.isActive ? 'Customer saved. Ready for the next movie.' : 'Customer deactivated. Booking history is preserved.');
    } catch (ex) { setError(`${saved ? 'Customer saved, but refreshing the list failed. Use Retry customers. ' : ''}${ex.message}`); }
    finally { setBusy(false); }
  }

  // A single controlled handler updates the matching customer form property.
  function changeField(event) {
    const { name, value, type, checked } = event.target;
    setForm({ ...form, [name]: type === 'checkbox' ? checked : value });
  }

  const tabs = mode === 'customer'
    ? [['browse', 'Browse movies'], ['bookings', 'My bookings']]
    : [['catalog', 'Movies & rooms'], ['showtimes', 'Showtimes'], ['reports', 'Reports']];

  return (
    <>
      <a className="skip-link" href="#main">Skip to content</a>
      <header className="site-header">
        <div className="header-inner">
          <div className="brand"><span className="brand-mark" aria-hidden="true">f.</span><div>FRAME<span>CINEMA & CO.</span></div></div>
          <div className="mode-switch" aria-label="Portal mode">
            <button type="button" aria-pressed={mode === 'customer'} onClick={() => changeMode('customer')}>Customer Portal</button>
            <button type="button" aria-pressed={mode === 'admin'} onClick={() => changeMode('admin')}>Admin Dashboard</button>
          </div>
          <span className="header-note">ONE THEATER. ENDLESS STORIES.</span>
        </div>
      </header>
      <div className="customer-bar">
        <div className="customer-inner">
          <label className="customer-picker">Active customer
            <select value={customerId} disabled={loading || busy || !customers.length} onChange={(e) => setCustomerId(e.target.value)}>
              {!customers.length && <option value="">{loading ? 'Loading customers…' : 'No active customers'}</option>}
              {customers.map((c) => <option key={c.customerId} value={c.customerId}>{c.firstName} {c.lastName} · {c.email}</option>)}
            </select>
          </label>
          <button type="button" className="text-button" disabled={busy} onClick={openAccounts}>Manage customers ↗</button>
          <span className="muted small">Your selection follows you across the portal.</span>
        </div>
      </div>
      <main id="main" className="shell">
        {error && <div className="alert error" role="alert">{error}<button type="button" className="text-button" disabled={busy} onClick={() => setReload(reload + 1)}>Retry customers</button></div>}
        {success && <div className="alert success" role="status">{success}</div>}
        {accountOpen && <section className="panel account-panel" aria-labelledby="account-heading">
          <div className="section-heading"><div><p className="eyebrow">CUSTOMER ACCOUNTS</p><h2 id="account-heading">A seat for everyone.</h2></div><button type="button" className="secondary" disabled={busy} onClick={() => setAccountOpen(false)}>Close</button></div>
          <label>Edit an account or create a new one
            <select value={editingId} disabled={busy} onChange={(e) => selectAccount(e.target.value)}>
              <option value="">+ Create a new customer</option>
              {accounts.map((c) => <option key={c.customerId} value={c.customerId}>{c.firstName} {c.lastName} ({c.isActive ? 'Active' : 'Inactive'})</option>)}
            </select>
          </label>
          <form onSubmit={saveCustomer}>
            <fieldset disabled={busy} className="form-grid">
              <label>First name<input name="firstName" value={form.firstName} onChange={changeField} required maxLength={50} /></label>
              <label>Last name<input name="lastName" value={form.lastName} onChange={changeField} required maxLength={50} /></label>
              <label>Email<input name="email" type="email" value={form.email} onChange={changeField} required maxLength={200} /></label>
              <label>Phone number<input name="phoneNumber" type="tel" value={form.phoneNumber} onChange={changeField} required maxLength={25} /></label>
              <label className="check"><input name="isActive" type="checkbox" checked={form.isActive} onChange={changeField} />Active customer</label>
              <div className="form-actions"><button type="submit">{busy ? 'Saving…' : editingId ? 'Save customer' : 'Create customer'}</button><button type="button" className="secondary" onClick={() => selectAccount('')}>New customer</button></div>
            </fieldset>
          </form>
        </section>}
        <nav className="view-tabs" aria-label="Views">
          {tabs.map(([id, label]) => <button type="button" key={id} aria-current={view === id ? 'page' : undefined} onClick={() => { setView(id); setSuccess(''); }}>{label}</button>)}
          <span className="view-label">{mode === 'customer' ? 'THE CUSTOMER COLLECTION' : 'THE CONTROL ROOM'}</span>
        </nav>
        {view === 'browse' && <BrowseMovies key={`browse-${customerId}`} customer={customer} />}
        {view === 'bookings' && <MyBookings key={`bookings-${customerId}`} customer={customer} />}
        {view === 'catalog' && <AdminMoviesRooms />}
        {view === 'showtimes' && <AdminShowtimes />}
        {view === 'reports' && <AdminReports />}
      </main>
      <footer className="site-footer"><span>FRAME CINEMA</span><span>Made for the big screen. Built for CIS 560.</span><span>Single theater · Multiple perspectives</span></footer>
    </>
  );
}
