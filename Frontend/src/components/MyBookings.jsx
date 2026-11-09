// Display one customer's reservations; SQL remains responsible for capacity and total prices.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { dateTime, money } from '../format.js';

export default function MyBookings({ customer }) {
  // Store confirmed rows separately from the ticket quantities being edited.
  const [bookings, setBookings] = useState([]);
  const [counts, setCounts] = useState({});
  // Loading and busy disable stale/duplicate actions; reload retries a failed GET request.
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [reload, setReload] = useState(0);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Read GET /bookings?customerId=... whenever the selected customer or retry changes.
  useEffect(() => {
    if (!customer) return;
    const controller = new AbortController();
    setLoading(true); setError('');
    api.getBookings(customer.customerId, controller.signal).then((rows) => {
      setBookings(rows);
      setCounts(Object.fromEntries(rows.map((b) => [b.bookingId, String(b.numberOfTickets)])));
    }).catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [customer, reload]);

  // PUT changes only NumberOfTickets; DELETE releases seats and removes the reservation.
  async function changeBooking(event, booking, cancel = false) {
    event.preventDefault();
    if (cancel && !window.confirm(`Cancel your booking for ${booking.title}?`)) return;
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      if (cancel) await api.deleteBooking(booking.bookingId);
      else await api.updateBooking(booking.bookingId, counts[booking.bookingId]);
      saved = true;
      const rows = await api.getBookings(customer.customerId);
      setBookings(rows);
      setCounts(Object.fromEntries(rows.map((b) => [b.bookingId, String(b.numberOfTickets)])));
      setSuccess(cancel ? 'Booking cancelled. Your seats are available again.' : 'Ticket count updated. Your new total is shown below.');
    } catch (ex) { setError(`${saved ? 'Change saved, but refreshing bookings failed. Use Refresh bookings. ' : ''}${ex.message}`); }
    finally { setBusy(false); }
  }

  return <section>
    <div className="page-heading"><p className="eyebrow">SAVED YOU A SEAT</p><h1>Your next<br /><em>great escape.</em></h1><p>Bookings for {customer ? `${customer.firstName} ${customer.lastName}` : 'your selected customer'}.</p></div>
    <div className="section-heading"><h2>My bookings <span className="count">{bookings.length}</span></h2><button type="button" className="secondary" disabled={busy || loading || !customer} onClick={() => setReload(reload + 1)}>Refresh bookings</button></div>
    {error && <div className="alert error" role="alert">{error}</div>}
    {success && <div className="alert success" role="status">{success}</div>}
    {!customer ? <p className="empty">Choose or create an active customer in the top bar to see bookings.</p> : loading ? <p className="empty" role="status">Loading your bookings…</p> : !bookings.length ? <p className="empty">No bookings yet. Browse the movie collection to plan your next visit.</p> : <div className="booking-list">{bookings.map((b) => <article className="panel reservation" key={b.bookingId}>
      <div className="reservation-number" aria-hidden="true">{String(b.bookingId).padStart(3, '0')}</div>
      <div className="reservation-info"><span className={`badge ${b.isCancelled ? 'negative' : 'positive'}`}>{b.isCancelled ? 'Screening cancelled' : 'Reserved'}</span><h3>{b.title}</h3><p>{dateTime(b.startDateTime)}</p><p className="muted">{b.roomName} · Room {b.roomNumber}</p><small className="muted">Booked {dateTime(b.bookingDate)}</small></div>
      <div className="reservation-price"><span>Confirmed total</span><strong>{money(b.totalPrice)}</strong><span>{b.numberOfTickets} {b.numberOfTickets === 1 ? 'ticket' : 'tickets'}</span></div>
      <form onSubmit={(e) => changeBooking(e, b)}><fieldset disabled={busy} className="reservation-actions"><label>Ticket count<input type="number" min="1" max="2147483647" step="1" required disabled={b.isCancelled} value={counts[b.bookingId] ?? ''} onChange={(e) => setCounts({ ...counts, [b.bookingId]: e.target.value })} /></label><button type="submit" disabled={b.isCancelled}>Update tickets</button><button type="button" className="secondary danger" onClick={(e) => changeBooking(e, b, true)}>Cancel booking</button></fieldset></form>
    </article>)}</div>}
    <p className="footnote">Updating a booking uses the current ticket price. Cancelled screenings keep their booking history until you cancel the booking.</p>
  </section>;
}
