// Browse the active catalog, then book a screening or manage the selected customer's review.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { dateTime, localDate, money } from '../format.js';

const emptyFilters = { title: '', genre: '', ageRating: '' };
const ratings = ['G', 'PG', 'PG-13', 'R', 'NC-17', 'NR'];

export default function BrowseMovies({ customer }) {
  // Draft filters change while typing; applied filters trigger a server-side search on submit.
  const [draft, setDraft] = useState(emptyFilters);
  const [filters, setFilters] = useState(emptyFilters);
  // Catalog data and the selected card determine which details to display.
  const [movies, setMovies] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [selected, setSelected] = useState(null);
  const [showtimes, setShowtimes] = useState([]);
  const [reviews, setReviews] = useState([]);
  // The review form starts at five stars and is populated from the customer's existing review.
  const [reviewForm, setReviewForm] = useState({ rating: '5', reviewText: '' });
  // Separate loading and write states prevent stale details and accidental duplicate submissions.
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [reload, setReload] = useState(0);
  const myReview = reviews.find((r) => r.customerId === customer?.customerId);
  const average = reviews.length ? (reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length).toFixed(1) : null;

  // Search GET /movies; also fetch room screen types because the Showtime DTO does not contain them.
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setError('');
    Promise.all([api.getMovies(filters, controller.signal), api.getRooms({ includeInactive: true }, controller.signal)])
      .then(([catalog, roomRows]) => { setMovies(catalog); setRooms(roomRows); })
      .catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [filters, reload]);

  // Fetch only the chosen movie's details; abort an older selection's requests when it changes.
  useEffect(() => {
    if (!selected) return;
    const controller = new AbortController();
    setDetailLoading(true); setShowtimes([]); setReviews([]); setError(''); setSuccess('');
    Promise.all([
      api.getShowtimes({ movieId: selected.movieId, firstDate: localDate() }, controller.signal),
      api.getReviews(selected.movieId, controller.signal),
    ]).then(([shows, reviewRows]) => {
      setShowtimes(shows.filter((s) => new Date(s.startDateTime) > new Date()));
      setReviews(reviewRows);
      const mine = reviewRows.find((r) => r.customerId === customer?.customerId);
      setReviewForm({ rating: String(mine?.rating ?? 5), reviewText: mine?.reviewText ?? '' });
    }).catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setDetailLoading(false); });
    return () => controller.abort();
  }, [selected, customer?.customerId]);

  // Submit trimmed query values to the C# search parameters and close the old selection.
  function search(event) {
    event.preventDefault();
    setSelected(null); setSuccess('');
    setFilters({ title: draft.title.trim(), genre: draft.genre.trim(), ageRating: draft.ageRating });
  }

  // POST sends just customerId/showtimeId/numberOfTickets; SQL calculates the price and checks seats.
  async function book(event, showtime) {
    event.preventDefault();
    if (!customer) return;
    const count = Number(new FormData(event.currentTarget).get('numberOfTickets'));
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      await api.createBooking({ customerId: customer.customerId, showtimeId: showtime.showtimeId, numberOfTickets: count });
      saved = true;
      const rows = await api.getShowtimes({ movieId: selected.movieId, firstDate: localDate() });
      setShowtimes(rows.filter((s) => new Date(s.startDateTime) > new Date()));
      setSuccess(`${count} ${count === 1 ? 'ticket' : 'tickets'} booked for ${customer.firstName}. See My bookings for the confirmed total.`);
    } catch (ex) { setError(`${saved ? 'Booking saved, but seat refresh failed. Check My bookings before trying again. ' : ''}${ex.message}`); }
    finally { setBusy(false); }
  }

  // A customer's existing review uses PUT; a new customer/movie pair uses POST.
  async function saveReview(event) {
    event.preventDefault();
    if (!customer) return;
    setBusy(true); setError(''); setSuccess('');
    let saved = false;
    try {
      const body = { customerId: customer.customerId, movieId: selected.movieId, rating: Number(reviewForm.rating), reviewText: reviewForm.reviewText.trim() || null };
      if (myReview) await api.updateReview(myReview.reviewId, body);
      else await api.createReview(body);
      saved = true;
      setReviews(await api.getReviews(selected.movieId));
      setSuccess('Your review has been saved. Thanks for sharing your perspective.');
    } catch (ex) { setError(`${saved ? 'Review saved, but refreshing reviews failed. ' : ''}${ex.message}`); }
    finally { setBusy(false); }
  }

  // DELETE removes only the selected customer's review, then refreshes the displayed average.
  async function deleteReview() {
    if (!myReview || !window.confirm('Remove your review for this movie?')) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await api.deleteReview(myReview.reviewId);
      setReviews(reviews.filter((r) => r.reviewId !== myReview.reviewId));
      setReviewForm({ rating: '5', reviewText: '' });
      setSuccess('Your review was removed.');
    } catch (ex) { setError(ex.message); }
    finally { setBusy(false); }
  }

  return (
    <div>
      <section className="hero"><div><p className="eyebrow">THE FRAME COLLECTION</p><h1>Good stories.<br /><em>Great company.</em></h1><p>Discover a new favorite, find your screening,<br className="desktop-break" /> and make a little time for the movies.</p></div><div className="hero-ticket" aria-hidden="true"><span>ADMIT ONE</span><strong>THE<br />BIG<br />SCREEN.</strong><span className="ticket-rule">YOUR NEXT STORY STARTS HERE</span><span>EST. 2026 &nbsp; / &nbsp; FRAME CINEMA</span></div></section>
      <form className="search-panel" onSubmit={search}>
        <label className="search-title">Find a film<input type="search" placeholder="Search movie titles…" maxLength={200} value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} /></label>
        <label>Genre<input placeholder="All genres" maxLength={50} value={draft.genre} onChange={(e) => setDraft({ ...draft, genre: e.target.value })} list="movie-genres" /><datalist id="movie-genres">{['Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Drama', 'Family', 'Fantasy', 'Horror', 'Musical', 'Mystery', 'Romance', 'Science Fiction', 'Thriller'].map((g) => <option key={g} value={g} />)}</datalist></label>
        <label>Age rating<select value={draft.ageRating} onChange={(e) => setDraft({ ...draft, ageRating: e.target.value })}><option value="">All ratings</option>{ratings.map((r) => <option key={r}>{r}</option>)}</select></label>
        <button type="submit" disabled={loading || busy}>Search films ↗</button>
      </form>
      {!selected && error && <div className="alert error" role="alert">{error}<button type="button" className="text-button" onClick={() => setReload(reload + 1)}>Retry catalog</button></div>}
      <div className="section-heading"><div><p className="eyebrow">SOMETHING FOR EVERYONE</p><h2>The movie collection<span className="count">{movies.length}</span></h2></div><span className="muted small">Classics, discoveries & everything in between</span></div>
      {!selected && (loading ? <p className="empty" role="status">Loading the collection…</p> : !movies.length && !error ? <p className="empty">No films match your search. Try another title, genre, or rating.</p> : <div className="movie-grid">
        {movies.map((m, index) => <button type="button" key={m.movieId} className={`movie-card tone-${index % 5} ${selected?.movieId === m.movieId ? 'selected' : ''}`} disabled={busy} aria-pressed={selected?.movieId === m.movieId} onClick={() => { setSelected(m); setError(''); }}>
          <div className="movie-art" aria-hidden="true"><span className="art-top">FRAME / THE COLLECTION</span><span className="art-number">{String(index + 1).padStart(2, '0')}</span><span className="art-genre">{m.genre}</span><span className="art-ring" /></div>
          <div className="movie-copy"><span className="movie-meta">{m.releaseDate.slice(0, 4)} <span>·</span> {m.runtimeMinutes} MIN <span className="rating-badge">{m.ageRating}</span></span><h3>{m.title}</h3><span className="movie-link">Showtimes & reviews <span>↗</span></span></div>
        </button>)}
      </div>)}
      {selected && <section className="panel movie-detail" aria-labelledby="selected-title">
        <div className="section-heading"><div><p className="eyebrow">YOUR NEXT NIGHT OUT</p><h2 id="selected-title">{selected.title}</h2><p className="muted">{selected.genre} · {selected.runtimeMinutes} minutes · {selected.ageRating}</p></div><button type="button" className="secondary" disabled={busy} onClick={() => setSelected(null)}>Close details</button></div>
        {selected.description && <p>{selected.description}</p>}
        {error && <div className="alert error" role="alert">{error}</div>}
        {success && <div className="alert success" role="status">{success}</div>}
        {detailLoading ? <p className="empty" role="status">Finding screenings and reviews…</p> : <>
          <div className="section-heading compact"><h3>Upcoming showtimes</h3><span className="muted small">All times are theater local time</span></div>
          {!customer && <p className="hint">Choose or create an active customer above to book tickets or leave a review.</p>}
          {!showtimes.length ? <p className="empty">No upcoming screenings for this film. Check back soon.</p> : <div className="showtime-grid">{showtimes.map((s) => <article className="showtime-card" key={s.showtimeId}>
            <span className="badge">{rooms.find((r) => r.screenRoomId === s.screenRoomId)?.screenType ?? 'Screening'}</span><h4>{dateTime(s.startDateTime)}</h4><p>{s.roomName} · Room {s.roomNumber}</p><div className="seat-line"><strong>{money(s.ticketPrice)} <small>/ ticket</small></strong><span className={`badge ${s.remainingSeats > 0 ? 'positive' : 'negative'}`}>{s.remainingSeats} seats left</span></div>
            <form onSubmit={(e) => book(e, s)}><fieldset disabled={busy || !customer || s.remainingSeats <= 0} className="booking-form"><label>Tickets<input aria-label={`Tickets for ${dateTime(s.startDateTime)}`} name="numberOfTickets" type="number" min="1" max={Math.max(1, s.remainingSeats)} step="1" defaultValue="1" required /></label><button type="submit">{busy ? 'Working…' : 'Book tickets'}</button></fieldset></form>
          </article>)}</div>}
          <div className="review-layout"><div><div className="section-heading compact"><h3>From the audience</h3><span className="badge">{average ? `★ ${average} / 5 · ${reviews.length} reviews` : 'No ratings yet'}</span></div>
            {!reviews.length ? <p className="empty">Be the first to share your thoughts.</p> : <div className="reviews">{reviews.map((r) => <article className="review" key={r.reviewId}><div className="section-heading compact"><strong>{r.firstName} {r.lastName}{r.customerId === customer?.customerId ? ' (you)' : ''}</strong><span className="stars" aria-label={`${r.rating} out of 5 stars`}>{'★'.repeat(r.rating)}{'☆'.repeat(5 - r.rating)}</span></div><p>{r.reviewText || 'This customer left a star rating.'}</p><span className="muted small">{dateTime(r.reviewDate)}</span></article>)}</div>}</div>
            <form className="review-editor" onSubmit={saveReview}><h3>{myReview ? 'Your perspective' : 'Leave a review'}</h3><p className="muted small">{myReview ? 'Update your existing review or remove it below.' : 'One review per customer, per movie.'}</p><fieldset disabled={busy || !customer}><label>Your rating<select value={reviewForm.rating} onChange={(e) => setReviewForm({ ...reviewForm, rating: e.target.value })}>{[5, 4, 3, 2, 1].map((r) => <option key={r} value={r}>{r} {r === 1 ? 'star' : 'stars'}</option>)}</select></label><label>Your thoughts<textarea rows="4" placeholder="What stayed with you?" value={reviewForm.reviewText} onChange={(e) => setReviewForm({ ...reviewForm, reviewText: e.target.value })} /></label><div className="form-actions"><button type="submit">{busy ? 'Saving…' : myReview ? 'Update review' : 'Post review'}</button>{myReview && <button type="button" className="danger secondary" onClick={deleteReview}>Delete review</button>}</div></fieldset></form>
          </div>
        </>}
      </section>}
    </div>
  );
}
