---
name: react-simple-ui
description: Use whenever creating or updating the React frontend components, pages, API helper, or styles in the /Frontend folder.
---

# Simple React (JavaScript) Frontend Skill

## 1. Simplicity & Tech Rules
- Use **Vite + React (JavaScript, `.jsx`)**. Do NOT use TypeScript.
- Use standard React hooks only (`useState`, `useEffect`). Do NOT use Redux, React Query, or complex routing libraries.
- Use a single clean `App.css` stylesheet with a modern, readable layout (cards, clean HTML tables, clear buttons, and status badges).
- **Comment every component, state variable, and `fetch` function** concisely so a student new to React can read the code top-to-bottom and understand how it works.

## 2. Exact 6-Component Structure (`/Frontend/src/`)
- `api.js` — Simple helper functions wrapping `fetch()` to call the C# backend (`http://localhost:5000/api/...`), returning JSON or throwing the backend's SQL error message.
- `App.jsx` — Holds the **Top Navigation Bar**:
  - Mode switcher: **Customer Portal** vs. **Admin Dashboard**.
  - **Active Customer Selector dropdown** (lists active customers from `GET /api/customers` plus a quick modal/form to create or edit a customer account, avoiding any need for passwords/login).
- **Customer Mode Views:**
  1. `components/BrowseMovies.jsx` — Search/filter movies by Title, Genre, or AgeRating. Clicking a movie expands:
     - **Upcoming Showtimes** (showing Room, Start Time, Ticket Price, **Remaining Seats**, and a "Book Tickets" input).
     - **Movie Reviews** (shows average rating, comments, and a form for the selected customer to add/update/delete their 1–5 star review).
  2. `components/MyBookings.jsx` — Lists all bookings for the selected customer, with an input to change `NumberOfTickets` (recalculates `TotalPrice` and checks capacity) or cancel (`DELETE`) the booking.
- **Admin Mode Views:**
  3. `components/AdminMoviesRooms.jsx` — Forms and tables to Add, Edit, and Toggle `IsActive` (soft-delete) for **Movies** and **ScreenRooms**.
  4. `components/AdminShowtimes.jsx` — Form and table to Schedule, Reschedule, or Cancel (`IsCancelled = 1`) **Showtimes**. Clearly displays any SQL overlap error returned by the backend.
  5. `components/AdminReports.jsx` — 4 sub-tabs for the **4 Aggregating Queries**:
     - *Movie Performance* (`FirstDate`, `LastDate` date inputs)
     - *Customer Booking Activity* (`FirstDate`, `LastDate` date inputs)
     - *Screen Room Utilization* (`FirstDate`, `LastDate` date inputs)
     - *Movie Review Summary* (`MinimumReviewCount` number input)
     Renders clean HTML tables that can be screenshotted directly for the CIS 560 Project Report.