// Four report tabs call the corresponding SQL aggregation endpoints and render screenshot-ready tables.
import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { localDate, money, number } from '../format.js';

// Column keys exactly match the camelCase result DTOs in Backend/Models/ReportResults.cs.
const reports = [
  { id: 'movie-performance', title: 'Movie performance', subtitle: 'The stories bringing people together.', dateBasis: 'Screening dates · Non-cancelled screenings', key: 'movieId', columns: [['movieId', 'Movie ID'], ['title', 'Movie'], ['showtimeCount', 'Showtimes'], ['ticketsSold', 'Tickets sold'], ['totalRevenue', 'Revenue', 'money'], ['averageTicketsPerShowtime', 'Avg. tickets / showtime']] },
  { id: 'customer-booking-activity', title: 'Customer booking activity', subtitle: 'Every regular has a favorite seat.', dateBasis: 'Booking dates · Includes retained bookings for cancelled screenings', key: 'customerId', columns: [['customerId', 'Customer ID'], ['customerName', 'Customer'], ['bookingCount', 'Bookings'], ['ticketsPurchased', 'Tickets'], ['totalSpent', 'Total spent', 'money'], ['spendingRank', 'Spending rank']] },
  { id: 'screen-room-utilization', title: 'Screen room utilization', subtitle: 'A closer look at every room.', dateBasis: 'Screening dates · Non-cancelled screenings', key: 'screenRoomId', columns: [['screenRoomId', 'Room ID'], ['roomNumber', 'Room'], ['showtimeCount', 'Showtimes'], ['ticketsBooked', 'Tickets booked'], ['seatsOffered', 'Seats offered'], ['occupancyRate', 'Occupancy', 'percent']] },
  { id: 'movie-review-summary', title: 'Movie review summary', subtitle: 'The audience has the final word.', dateBasis: 'All review dates · Movies meeting the minimum count', key: 'movieId', columns: [['movieId', 'Movie ID'], ['title', 'Movie'], ['reviewCount', 'Reviews'], ['averageRating', 'Average rating', 'stars'], ['highestRating', 'Highest rating'], ['lowestRating', 'Lowest rating']] },
];

// Format display values while preserving null ratings as a readable em dash.
function cell(value, type) {
  if (value == null) return '—';
  if (type === 'money') return money(value);
  if (type === 'percent') return `${Number(value).toFixed(2)}%`;
  if (type === 'stars') return `${Number(value).toFixed(2)} / 5`;
  return typeof value === 'number' ? number(value) : value;
}

export default function AdminReports() {
  // Changing the active tab selects a report definition, result columns, and its endpoint.
  const [tab, setTab] = useState(reports[0].id);
  // Wide relative defaults cover past bookings and all 30 days of the current seed schedule.
  const [firstDate, setFirstDate] = useState(localDate(-60));
  const [lastDate, setLastDate] = useState(localDate(60));
  const [minimumReviewCount, setMinimumReviewCount] = useState('1');
  // Applied filters describe the displayed table, even while the form contains unsaved edits.
  const [applied, setApplied] = useState({ firstDate: localDate(-60), lastDate: localDate(60), minimumReviewCount: 1 });
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const report = reports.find((r) => r.id === tab);
  const isReviews = tab === 'movie-review-summary';

  // Fetch only the selected report and its allowed parameters; abort stale tab/date requests.
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setRows([]); setError('');
    const filters = tab === 'movie-review-summary'
      ? { minimumReviewCount: applied.minimumReviewCount }
      : { firstDate: applied.firstDate, lastDate: applied.lastDate };
    api.getReport(tab, filters, controller.signal).then(setRows)
      .catch((ex) => { if (ex.name !== 'AbortError') setError(ex.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [tab, applied, reload]);

  // Clear the old report in the same render as a tab change: each report has different row IDs.
  function changeReport(id) {
    if (id === tab) return;
    setRows([]);
    setLoading(true);
    setTab(id);
  }

  // Submit a fresh filter snapshot; reject reversed dates before making the SQL call.
  function runReport(event) {
    event.preventDefault();
    if (!isReviews && firstDate > lastDate) { setError('The first date must be on or before the last date.'); return; }
    setApplied({ firstDate, lastDate, minimumReviewCount: Number(minimumReviewCount) });
  }

  return <section className="reports-page">
    <div className="page-heading"><p className="eyebrow">THE CONTROL ROOM / INSIGHTS</p><h1>Behind the screen.<br /><em>Inside the numbers.</em></h1><p>Four perspectives on the theater, ready for a closer look.</p></div>
    <nav className="subtabs report-tabs" aria-label="Report selection">{reports.map((r, i) => <button type="button" key={r.id} aria-pressed={tab === r.id} onClick={() => changeReport(r.id)}><span className="tab-number">0{i + 1}</span>{r.title}</button>)}</nav>
    <form onSubmit={runReport} className="panel report-filters"><fieldset disabled={loading} className="filter-row">
      {isReviews ? <label>Minimum review count<input type="number" min="0" max="2147483647" step="1" value={minimumReviewCount} onChange={(e) => setMinimumReviewCount(e.target.value)} required /></label> : <><label>First date<input type="date" value={firstDate} onChange={(e) => setFirstDate(e.target.value)} required /></label><label>Last date<input type="date" min={firstDate} value={lastDate} onChange={(e) => setLastDate(e.target.value)} required /></label></>}
      <button type="submit">{loading ? 'Running report…' : 'Run report ↗'}</button>
    </fieldset></form>
    {error && <div className="alert error" role="alert">{error}<button type="button" className="text-button" disabled={loading} onClick={() => setReload(reload + 1)}>Retry report</button></div>}
    <article className="panel report-sheet">
      <div className="report-heading"><div><p className="eyebrow">FRAME CINEMA / THEATER REPORT</p><h2>{report.title}</h2><p>{report.subtitle}</p></div><div className="report-period">{isReviews ? `At least ${applied.minimumReviewCount} ${applied.minimumReviewCount === 1 ? 'review' : 'reviews'}` : <>{applied.firstDate}<br /><span>through {applied.lastDate}</span></>}</div></div>
      <div className="report-meta"><span>{report.dateBasis}</span><span>{loading ? 'Loading…' : `${rows.length} records`}</span></div>
      {loading ? <p className="empty" role="status">Preparing your report…</p> : <div className="table-wrap"><table className="report-table"><caption className="sr-only">{report.title} · {isReviews ? `minimum ${applied.minimumReviewCount} reviews` : `${applied.firstDate} through ${applied.lastDate}`}</caption><thead><tr>{report.columns.map(([key, label]) => <th scope="col" key={key} className={['title', 'customerName', 'roomNumber'].includes(key) ? '' : 'numeric'}>{label}</th>)}</tr></thead><tbody>{rows.map((row) => <tr key={row[report.key]}>{report.columns.map(([key, , type]) => <td key={key} className={typeof row[key] === 'number' || type ? 'numeric' : ''}>{cell(row[key], type)}</td>)}</tr>)}{!rows.length && <tr><td colSpan={report.columns.length} className="empty">{error ? 'Report could not be loaded. See the message above.' : 'No records match these filters.'}</td></tr>}</tbody></table></div>}
      <div className="report-bottom"><span>CIS 560 · MOVIE THEATER BOOKING SYSTEM</span><span>{isReviews ? 'Ratings are out of 5 stars.' : 'Date range includes both endpoints.'}</span></div>
    </article>
  </section>;
}
