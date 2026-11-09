// Every request goes to our ASP.NET Core controller routes, using camelCase JSON.
const BASE_URL = 'http://localhost:5000/api';

// Encode optional query filters safely; omit empty filters so SQL receives its defaults.
export function queryString(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== '' && value !== null && value !== undefined) query.set(key, String(value));
  });
  return query.size ? `?${query}` : '';
}

// Execute fetch, handle DELETE's empty 204 response, and preserve exact SQL error messages.
async function request(path, { method = 'GET', body, signal } = {}) {
  let response;
  try {
    response = await fetch(`${BASE_URL}${path}`, {
      method, signal,
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    if (error.name === 'AbortError') throw error;
    throw new Error('Cannot reach the cinema API. Start the backend at http://localhost:5000 and try again.');
  }
  if (response.status === 204) return null;
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = null; }
  if (!response.ok) {
    // SQL THROW/constraint errors use error; ASP.NET input validation uses an errors dictionary.
    const validation = data?.errors ? Object.values(data.errors).flat().join(' ') : '';
    throw new Error(data?.error || validation || `Request failed (${response.status}). Please try again.`);
  }
  return data;
}

// Full-replacement PUT bodies contain only properties declared by the C# request DTOs.
export const moviePayload = (m) => ({
  title: m.title.trim(), releaseDate: m.releaseDate, genre: m.genre.trim(),
  runtimeMinutes: Number(m.runtimeMinutes), ageRating: m.ageRating,
  description: m.description?.trim() || null, isActive: m.isActive,
});
export const roomPayload = (r) => ({
  roomNumber: r.roomNumber.trim(), name: r.name.trim(), screenType: r.screenType,
  capacity: Number(r.capacity), isActive: r.isActive,
});
export const customerPayload = (c) => ({
  firstName: c.firstName.trim(), lastName: c.lastName.trim(), email: c.email.trim(),
  phoneNumber: c.phoneNumber.trim(), isActive: c.isActive,
});
export const showtimePayload = (s) => ({
  movieId: Number(s.movieId), screenRoomId: Number(s.screenRoomId),
  // datetime-local supplies a local string; do not convert DATETIME2 values to UTC.
  startDateTime: s.startDateTime, ticketPrice: Number(s.ticketPrice), isCancelled: s.isCancelled,
});

// GET helpers accept an AbortSignal so effects can discard obsolete requests on navigation.
// POST/PUT/DELETE helpers map directly to the seven backend controllers.
export const api = {
  getMovies: (filters, signal) => request(`/movies${queryString(filters)}`, { signal }),
  createMovie: (body) => request('/movies', { method: 'POST', body: moviePayload(body) }),
  updateMovie: (id, body) => request(`/movies/${id}`, { method: 'PUT', body: moviePayload(body) }),
  getRooms: (filters, signal) => request(`/screenrooms${queryString(filters)}`, { signal }),
  createRoom: (body) => request('/screenrooms', { method: 'POST', body: roomPayload(body) }),
  updateRoom: (id, body) => request(`/screenrooms/${id}`, { method: 'PUT', body: roomPayload(body) }),
  getCustomers: (filters, signal) => request(`/customers${queryString(filters)}`, { signal }),
  createCustomer: (body) => request('/customers', { method: 'POST', body: customerPayload(body) }),
  updateCustomer: (id, body) => request(`/customers/${id}`, { method: 'PUT', body: customerPayload(body) }),
  getShowtimes: (filters, signal) => request(`/showtimes${queryString(filters)}`, { signal }),
  createShowtime: (body) => request('/showtimes', { method: 'POST', body: showtimePayload(body) }),
  updateShowtime: (id, body) => request(`/showtimes/${id}`, { method: 'PUT', body: showtimePayload(body) }),
  getBookings: (customerId, signal) => request(`/bookings${queryString({ customerId })}`, { signal }),
  createBooking: (body) => request('/bookings', { method: 'POST', body }),
  updateBooking: (id, numberOfTickets) => request(`/bookings/${id}`, { method: 'PUT', body: { numberOfTickets: Number(numberOfTickets) } }),
  deleteBooking: (id) => request(`/bookings/${id}`, { method: 'DELETE' }),
  getReviews: (movieId, signal) => request(`/reviews${queryString({ movieId })}`, { signal }),
  createReview: (body) => request('/reviews', { method: 'POST', body }),
  updateReview: (id, body) => request(`/reviews/${id}`, { method: 'PUT', body }),
  deleteReview: (id) => request(`/reviews/${id}`, { method: 'DELETE' }),
  getReport: (name, filters, signal) => request(`/reports/${name}${queryString(filters)}`, { signal }),
};
