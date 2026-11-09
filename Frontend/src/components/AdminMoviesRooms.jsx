// Manage the catalog and physical rooms through full-replacement API requests and soft deletes.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { localDate } from '../format.js';

const newMovie = () => ({ title: '', releaseDate: localDate(), genre: '', runtimeMinutes: '120', ageRating: 'PG-13', description: '', isActive: true });
const newRoom = () => ({ roomNumber: '', name: '', screenType: 'Standard', capacity: '100', isActive: true });

export default function AdminMoviesRooms() {
  // The sub-tab selects the resource; both complete lists include soft-deleted records.
  const [tab, setTab] = useState('movies');
  const [movies, setMovies] = useState([]);
  const [rooms, setRooms] = useState([]);
  // One form is reused for create/edit; an empty editId means POST rather than PUT.
  const [editId, setEditId] = useState(null);
  const [form, setForm] = useState(newMovie);
  // Loading/busy protect writes, while reload provides an explicit retry after a read failure.
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [reload, setReload] = useState(0);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const isMovie = tab === 'movies';

  // Request both admin lists, including inactive rows so soft deletes can be reversed.
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setError('');
    Promise.all([api.getMovies({ includeInactive: true }, controller.signal), api.getRooms({ includeInactive: true }, controller.signal)])
      .then(([m, r]) => { setMovies(m); setRooms(r); })
      .catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [reload]);

  // Change resources and discard the previous editor so fields never cross between DTOs.
  function changeTab(next) {
    setTab(next); setEditId(null); setForm(next === 'movies' ? newMovie() : newRoom());
    setError(''); setSuccess('');
  }

  // Start a new form or copy a saved row; payload helpers omit response-only identifiers.
  function edit(row) {
    setEditId(row ? (isMovie ? row.movieId : row.screenRoomId) : null);
    setForm(row ? { ...row, description: row.description ?? '' } : isMovie ? newMovie() : newRoom());
    setError(''); setSuccess('');
    document.getElementById('catalog-editor')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // Maintain a controlled form, preserving booleans for the IsActive checkbox.
  function changeField(event) {
    const { name, value, type, checked } = event.target;
    setForm({ ...form, [name]: type === 'checkbox' ? checked : value });
  }

  // Save or toggle IsActive using PUT; there are no hard-delete endpoints for these resources.
  async function save(event, toggleRow = null) {
    event?.preventDefault();
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      const body = toggleRow ? { ...toggleRow, isActive: !toggleRow.isActive } : form;
      const id = toggleRow ? (isMovie ? toggleRow.movieId : toggleRow.screenRoomId) : editId;
      if (isMovie) {
        if (id) await api.updateMovie(id, body); else await api.createMovie(body);
      } else {
        if (id) await api.updateRoom(id, body); else await api.createRoom(body);
      }
      saved = true;
      const [m, r] = await Promise.all([api.getMovies({ includeInactive: true }), api.getRooms({ includeInactive: true })]);
      setMovies(m); setRooms(r);
      // Clear the editor so it cannot later overwrite a freshly toggled status with an old value.
      setEditId(null); setForm(isMovie ? newMovie() : newRoom());
      setSuccess(`${isMovie ? 'Movie' : 'Room'} ${toggleRow ? (body.isActive ? 'reactivated' : 'deactivated') : 'saved'} successfully.`);
    } catch (ex) { setError(`${saved ? 'Change saved, but refreshing the catalog failed. Use Refresh lists. ' : ''}${ex.message}`); }
    finally { setBusy(false); }
  }

  return <section>
    <div className="page-heading"><p className="eyebrow">THE CONTROL ROOM / CATALOG</p><h1>Set the scene.<br /><em>Keep it running.</em></h1><p>A thoughtful collection. A room for every kind of story.</p></div>
    <div className="section-heading"><div className="subtabs" aria-label="Catalog resource"><button type="button" aria-pressed={isMovie} disabled={busy} onClick={() => changeTab('movies')}>Movies <span>{movies.length}</span></button><button type="button" aria-pressed={!isMovie} disabled={busy} onClick={() => changeTab('rooms')}>Screen rooms <span>{rooms.length}</span></button></div><button type="button" className="secondary" disabled={busy || loading} onClick={() => setReload(reload + 1)}>Refresh lists</button></div>
    {error && <div className="alert error" role="alert">{error}</div>}
    {success && <div className="alert success" role="status">{success}</div>}
    <section id="catalog-editor" className="panel editor" aria-labelledby="catalog-editor-title">
      <div className="section-heading compact"><h2 id="catalog-editor-title">{editId ? `Edit ${isMovie ? 'movie' : 'room'} #${editId}` : `Add a ${isMovie ? 'movie' : 'screen room'}`}</h2>{editId && <button type="button" className="secondary" disabled={busy} onClick={() => edit(null)}>Cancel edit</button>}</div>
      <form onSubmit={save}><fieldset disabled={busy || loading} className="form-grid">
        {isMovie ? <>
          <label className="wide">Movie title<input name="title" value={form.title ?? ''} onChange={changeField} maxLength={200} required /></label>
          <label>Release date<input type="date" name="releaseDate" value={form.releaseDate ?? ''} onChange={changeField} required /></label>
          <label>Genre<input name="genre" value={form.genre ?? ''} onChange={changeField} maxLength={50} required /></label>
          <label>Runtime (minutes)<input type="number" name="runtimeMinutes" value={form.runtimeMinutes ?? ''} onChange={changeField} min="1" max="2147483647" step="1" required /></label>
          <label>Age rating<select name="ageRating" value={form.ageRating ?? 'PG-13'} onChange={changeField}>{['G', 'PG', 'PG-13', 'R', 'NC-17', 'NR'].map((r) => <option key={r}>{r}</option>)}</select></label>
          <label className="full">Description<textarea name="description" rows="2" value={form.description ?? ''} onChange={changeField} /></label>
        </> : <>
          <label>Room number<input name="roomNumber" value={form.roomNumber ?? ''} onChange={changeField} maxLength={100} required /></label>
          <label>Room name<input name="name" value={form.name ?? ''} onChange={changeField} maxLength={100} required /></label>
          <label>Screen type<select name="screenType" value={form.screenType ?? 'Standard'} onChange={changeField}>{['Standard', 'IMAX', 'Dolby', '3D'].map((s) => <option key={s}>{s}</option>)}</select></label>
          <label>Seat capacity<input name="capacity" type="number" value={form.capacity ?? ''} onChange={changeField} min="1" max="2147483647" step="1" required /></label>
        </>}
        <label className="check"><input name="isActive" type="checkbox" checked={form.isActive ?? true} onChange={changeField} />Active {isMovie ? 'movie' : 'room'}</label>
        <div className="form-actions"><button type="submit">{busy ? 'Saving…' : editId ? 'Save changes' : isMovie ? 'Add movie' : 'Add room'}</button></div>
      </fieldset></form>
    </section>
    <div className="section-heading"><h2>{isMovie ? 'The movie catalog' : 'Our screening rooms'}</h2><span className="muted small">Includes inactive records · History stays intact</span></div>
    {loading ? <p className="empty" role="status">Loading the catalog…</p> : <div className="table-wrap"><table><caption className="sr-only">{isMovie ? 'All movies' : 'All screen rooms'}, including inactive records</caption><thead><tr>{(isMovie ? ['Movie', 'Genre', 'Released', 'Runtime', 'Rating', 'Status', 'Manage'] : ['Room', 'Name', 'Screen type', 'Capacity', 'Status', 'Manage']).map((label) => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>
      {isMovie ? movies.map((m) => <tr key={m.movieId}><th scope="row">{m.title}</th><td>{m.genre}</td><td>{m.releaseDate}</td><td>{m.runtimeMinutes} min</td><td><span className="rating-badge">{m.ageRating}</span></td><td><span className={`badge ${m.isActive ? 'positive' : 'neutral'}`}>{m.isActive ? 'Active' : 'Inactive'}</span></td><td><div className="table-actions"><button type="button" className="secondary small-button" disabled={busy} onClick={() => edit(m)}>Edit<span className="sr-only"> {m.title}</span></button><button type="button" className="secondary small-button" disabled={busy} onClick={() => save(null, m)}>{m.isActive ? 'Deactivate' : 'Reactivate'}<span className="sr-only"> {m.title}</span></button></div></td></tr>) : rooms.map((r) => <tr key={r.screenRoomId}><th scope="row">{r.roomNumber}</th><td>{r.name}</td><td>{r.screenType}</td><td>{r.capacity}</td><td><span className={`badge ${r.isActive ? 'positive' : 'neutral'}`}>{r.isActive ? 'Active' : 'Inactive'}</span></td><td><div className="table-actions"><button type="button" className="secondary small-button" disabled={busy} onClick={() => edit(r)}>Edit<span className="sr-only"> {r.name}</span></button><button type="button" className="secondary small-button" disabled={busy} onClick={() => save(null, r)}>{r.isActive ? 'Deactivate' : 'Reactivate'}<span className="sr-only"> {r.name}</span></button></div></td></tr>)}
      {!(isMovie ? movies : rooms).length && <tr><td colSpan={isMovie ? 7 : 6} className="empty">No {isMovie ? 'movies' : 'rooms'} yet. Add the first one above.</td></tr>}
    </tbody></table></div>}
  </section>;
}
