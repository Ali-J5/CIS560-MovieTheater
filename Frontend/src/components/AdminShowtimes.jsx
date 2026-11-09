// Schedule/reschedule screenings; the stored procedures enforce runtime overlap and capacity rules.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { dateTime, localDate, money } from '../format.js';

const emptyShowtime = () => ({ movieId: '', screenRoomId: '', startDateTime: `${localDate()}T18:00`, ticketPrice: '12.00', isCancelled: false });

export default function AdminShowtimes() {
  // Load names for the selectors alongside the screening rows displayed in the table.
  const [showtimes, setShowtimes] = useState([]);
  const [movies, setMovies] = useState([]);
  const [rooms, setRooms] = useState([]);
  // Store the complete editable Showtime DTO and the existing identifier, if any.
  const [form, setForm] = useState(emptyShowtime);
  const [editId, setEditId] = useState(null);
  // Table filters are local; loading/busy and notices track database request outcomes.
  const [fromDate, setFromDate] = useState(localDate(-30));
  const [showCancelled, setShowCancelled] = useState(true);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [reload, setReload] = useState(0);

  // Include historical/inactive choices to display and edit existing references accurately.
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setError('');
    Promise.all([api.getShowtimes({ includeCancelled: true }, controller.signal), api.getMovies({ includeInactive: true }, controller.signal), api.getRooms({ includeInactive: true }, controller.signal)])
      .then(([s, m, r]) => { setShowtimes(s); setMovies(m); setRooms(r); })
      .catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [reload]);

  // Preserve the theater-local timestamp; datetime-local must not go through toISOString().
  function edit(row) {
    setEditId(row?.showtimeId ?? null);
    setForm(row ? { movieId: row.movieId, screenRoomId: row.screenRoomId, startDateTime: row.startDateTime.slice(0, 19), ticketPrice: row.ticketPrice, isCancelled: row.isCancelled } : emptyShowtime());
    setError(''); setSuccess('');
    document.getElementById('showtime-editor')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // Controlled form updates keep numeric text until api.js builds the typed JSON payload.
  function changeField(event) {
    const { name, value, type, checked } = event.target;
    setForm({ ...form, [name]: type === 'checkbox' ? checked : value });
  }

  // POST schedules; PUT reschedules or toggles IsCancelled without deleting history.
  async function save(event, toggleRow = null) {
    event?.preventDefault();
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      const body = toggleRow ? { ...toggleRow, isCancelled: !toggleRow.isCancelled } : form;
      const id = toggleRow?.showtimeId ?? editId;
      if (id) await api.updateShowtime(id, body); else await api.createShowtime(body);
      saved = true;
      setShowtimes(await api.getShowtimes({ includeCancelled: true }));
      setEditId(null); setForm(emptyShowtime());
      setSuccess(toggleRow ? (body.isCancelled ? 'Screening cancelled. Existing bookings remain in history.' : 'Screening restored successfully.') : 'Showtime saved. The room is ready for its next story.');
    } catch (ex) {
      // Preserve the exact SQL THROW message, including runtime overlap and capacity errors.
      setError(`${saved ? 'Showtime saved, but refreshing the schedule failed. Use Refresh schedule. ' : ''}${ex.message}`);
    } finally { setBusy(false); }
  }

  const visible = showtimes.filter((s) => (!fromDate || s.startDateTime.slice(0, 10) >= fromDate) && (showCancelled || !s.isCancelled));
  return <section>
    <div className="page-heading"><p className="eyebrow">THE CONTROL ROOM / SCHEDULE</p><h1>Make room<br /><em>for the next story.</em></h1><p>Schedule screenings, keep an eye on seats, and make every room count.</p></div>
    {error && <div className="alert error" role="alert"><strong>Unable to complete the request.</strong><span>{error}</span></div>}
    {success && <div className="alert success" role="status">{success}</div>}
    <section id="showtime-editor" className="panel editor" aria-labelledby="showtime-editor-title">
      <div className="section-heading compact"><h2 id="showtime-editor-title">{editId ? `Edit showtime #${editId}` : 'Schedule a screening'}</h2>{editId && <button type="button" className="secondary" disabled={busy} onClick={() => edit(null)}>Cancel edit</button>}</div>
      <form onSubmit={save}><fieldset disabled={busy || loading} className="form-grid">
        <label className="wide">Movie<select name="movieId" value={form.movieId} onChange={changeField} required><option value="">Choose a movie</option>{movies.filter((m) => m.isActive || m.movieId === Number(form.movieId)).map((m) => <option key={m.movieId} value={m.movieId}>{m.title} · {m.runtimeMinutes} min{!m.isActive ? ' (Inactive)' : ''}</option>)}</select></label>
        <label className="wide">Screen room<select name="screenRoomId" value={form.screenRoomId} onChange={changeField} required><option value="">Choose a room</option>{rooms.filter((r) => r.isActive || r.screenRoomId === Number(form.screenRoomId)).map((r) => <option key={r.screenRoomId} value={r.screenRoomId}>{r.roomNumber} · {r.name} · {r.screenType} · {r.capacity} seats{!r.isActive ? ' (Inactive)' : ''}</option>)}</select></label>
        <label className="wide">Start date & time (theater local)<input name="startDateTime" type="datetime-local" step="1" value={form.startDateTime} onChange={changeField} required /></label>
        <label>Ticket price ($)<input name="ticketPrice" type="number" min="0" max="99999999.99" step="0.01" value={form.ticketPrice} onChange={changeField} required /></label>
        <label className="check"><input name="isCancelled" type="checkbox" checked={form.isCancelled} onChange={changeField} />Cancelled</label>
        <div className="form-actions full"><button type="submit">{busy ? 'Saving…' : editId ? 'Save showtime' : 'Schedule showtime'}</button><span className="muted small">Each screening reserves the room for the movie's full runtime.</span></div>
      </fieldset></form>
    </section>
    <div className="section-heading"><div><h2>The screening schedule <span className="count">{visible.length}</span></h2><p className="muted small">Seats remaining are calculated from current bookings.</p></div><button type="button" className="secondary" disabled={busy || loading} onClick={() => setReload(reload + 1)}>Refresh schedule</button></div>
    <div className="filter-row"><label>Show from<input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} /></label><label className="check"><input type="checkbox" checked={showCancelled} onChange={(e) => setShowCancelled(e.target.checked)} />Include cancelled screenings</label></div>
    {loading ? <p className="empty" role="status">Loading the schedule…</p> : <div className="table-wrap"><table><caption className="sr-only">Screening schedule with remaining seats and management actions</caption><thead><tr>{['Movie', 'Room', 'Starts', 'Price', 'Sold / capacity', 'Remaining', 'Status', 'Manage'].map((h) => <th key={h} scope="col">{h}</th>)}</tr></thead><tbody>{visible.map((s) => <tr key={s.showtimeId}><th scope="row">{s.title}</th><td>{s.roomName}<small className="cell-note">Room {s.roomNumber} · {rooms.find((r) => r.screenRoomId === s.screenRoomId)?.screenType}</small></td><td className="nowrap">{dateTime(s.startDateTime)}</td><td className="numeric">{money(s.ticketPrice)}</td><td className="numeric">{s.ticketsSold} / {s.roomCapacity}</td><td className="numeric">{s.remainingSeats}</td><td><span className={`badge ${s.isCancelled ? 'negative' : 'positive'}`}>{s.isCancelled ? 'Cancelled' : 'Scheduled'}</span></td><td><div className="table-actions"><button type="button" className="secondary small-button" disabled={busy} onClick={() => edit(s)}>Edit<span className="sr-only"> showtime {s.showtimeId}</span></button><button type="button" className={`secondary small-button ${!s.isCancelled ? 'danger' : ''}`} disabled={busy} onClick={() => save(null, s)}>{s.isCancelled ? 'Restore' : 'Cancel'}<span className="sr-only"> showtime {s.showtimeId}</span></button></div></td></tr>)}{!visible.length && <tr><td colSpan="8" className="empty">No screenings match these filters. Schedule one above or choose an earlier date.</td></tr>}</tbody></table></div>}
  </section>;
}
