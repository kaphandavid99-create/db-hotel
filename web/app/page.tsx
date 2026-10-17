"use client";

import { useMemo, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ArrowDownToLine,
  ArrowRight,
  BedDouble,
  CalendarDays,
  Check,
  ChevronDown,
  CircleDollarSign,
  ClipboardList,
  ConciergeBell,
  LayoutDashboard,
  Menu,
  Plus,
  Search,
  SlidersHorizontal,
  Sparkles,
  Users,
  X,
} from "lucide-react";
import WorkspacePage, { type WorkspaceSection } from "./workspace-page";
import { roomCapacities, roomRates } from "./pricing";
import { revealItem, staggerContainer } from "./motion";

type ReservationStatus = "confirmed" | "pending" | "completed" | "cancelled";
type Reservation = {
  id: string;
  guest: string;
  email: string;
  phone: string;
  room: string;
  roomType: string;
  checkIn: string;
  checkOut: string;
  guests: number;
  status: ReservationStatus;
  total: number;
};

const today = "2026-10-17";
const initialReservations: Reservation[] = [
  { id: "RS-2048", guest: "Amelia Warren", email: "amelia.warren@email.com", phone: "+237 6 70 00 01 48", room: "308", roomType: "Deluxe King", checkIn: today, checkOut: "2026-10-20", guests: 2, status: "confirmed", total: 195_000 },
  { id: "RS-2047", guest: "Noah Bennett", email: "noah.b@email.com", phone: "+237 6 70 00 01 47", room: "214", roomType: "Garden Queen", checkIn: today, checkOut: "2026-10-19", guests: 1, status: "pending", total: 90_000 },
  { id: "RS-2046", guest: "Sofia Laurent", email: "sofia.l@email.com", phone: "+237 6 70 00 01 46", room: "501", roomType: "Harbor Suite", checkIn: today, checkOut: "2026-10-22", guests: 2, status: "confirmed", total: 625_000 },
  { id: "RS-2045", guest: "Oliver Chen", email: "oliver.chen@email.com", phone: "+237 6 70 00 01 45", room: "116", roomType: "Courtyard Twin", checkIn: "2026-10-16", checkOut: "2026-10-18", guests: 2, status: "confirmed", total: 100_000 },
  { id: "RS-2044", guest: "Isabella Reed", email: "isabella.r@email.com", phone: "+237 6 70 00 01 44", room: "402", roomType: "Deluxe King", checkIn: "2026-10-15", checkOut: today, guests: 1, status: "completed", total: 130_000 },
];
const navigation = [
  { label: "Overview", href: "/", icon: LayoutDashboard },
  { label: "Reservations", href: "/reservations", icon: CalendarDays },
  { label: "Rooms", href: "/rooms", icon: BedDouble },
  { label: "Guests", href: "/guests", icon: Users },
  { label: "Services", href: "/services", icon: ConciergeBell },
  { label: "Billing", href: "/billing", icon: CircleDollarSign },
];
const money = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "XAF", maximumFractionDigits: 0 });

function formatDate(value: string) {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" }).format(new Date(`${value}T12:00:00`));
}

export default function Home({ section = "" }: { section?: string }) {
  const [reservations, setReservations] = useState(initialReservations);
  const reduceMotion = useReducedMotion();
  const router = useRouter();
  const activeNav = navigation.find(({ href }) => href === (section ? `/${section}` : "/"))?.label ?? "Overview";
  const activeSection = activeNav === "Overview" ? null : activeNav as WorkspaceSection;
  const [filter, setFilter] = useState<"all" | ReservationStatus>("all");
  const [roomTypeFilter, setRoomTypeFilter] = useState("all");
  const [reservationSort, setReservationSort] = useState("checkIn");
  const [showReservationFilters, setShowReservationFilters] = useState(false);
  const [showPropertyMenu, setShowPropertyMenu] = useState(false);
  const [showRoomStatusMenu, setShowRoomStatusMenu] = useState(false);
  const [roomStatusFilter, setRoomStatusFilter] = useState("all");
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [mobileNav, setMobileNav] = useState(false);
  const [notice, setNotice] = useState("");
  const [formError, setFormError] = useState("");
  const [selectedRoomType, setSelectedRoomType] = useState("Garden Queen");

  function navigateTo(section: string) {
    const destination = navigation.find((item) => item.label === section);
    if (destination) router.push(destination.href);
    setMobileNav(false);
  }

  const visibleReservations = useMemo(() => reservations
    .filter((reservation) => {
      const query = `${reservation.guest} ${reservation.id} ${reservation.email} ${reservation.phone} ${reservation.room} ${reservation.roomType} ${reservation.status}`.toLowerCase();
      return query.includes(search.trim().toLowerCase())
        && (filter === "all" || reservation.status === filter)
        && (roomTypeFilter === "all" || reservation.roomType === roomTypeFilter);
    })
    .sort((first, second) => {
      if (reservationSort === "total-desc") return second.total - first.total;
      if (reservationSort === "total-asc") return first.total - second.total;
      return first.checkIn.localeCompare(second.checkIn);
    }), [filter, reservations, reservationSort, roomTypeFilter, search]);

  const roomStatuses = [
    { id: "available", label: "Available", count: 18, dot: "dot-available", bars: "" },
    { id: "occupied", label: "Occupied", count: 54, dot: "dot-occupied", bars: "bars-green" },
    { id: "being_cleaned", label: "Being cleaned", count: 5, dot: "dot-cleaning", bars: "bars-orange" },
    { id: "out_of_service", label: "Out of service", count: 3, dot: "dot-out", bars: "bars-gray" },
  ];
  const visibleRoomStatuses = roomStatuses.filter((status) => roomStatusFilter === "all" || status.id === roomStatusFilter);

  function createReservation(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const firstName = String(form.get("firstName") ?? "").trim();
    const lastName = String(form.get("lastName") ?? "").trim();
    const email = String(form.get("email") ?? "").trim();
    const phone = String(form.get("phone") ?? "").trim();
    const checkIn = String(form.get("checkIn") ?? "");
    const checkOut = String(form.get("checkOut") ?? "");
    const guests = Number(form.get("guests"));
    const roomType = String(form.get("roomType") ?? "");
    if (!firstName || !lastName || !email || !phone || !checkIn || !checkOut || guests < 1) {
      setFormError("Complete each required field with at least one guest.");
      return;
    }
    if (reservations.some((reservation) => reservation.email.toLowerCase() === email.toLowerCase() || reservation.phone === phone)) {
      setFormError("A client with this email address or phone number already exists.");
      return;
    }
    if (checkOut <= checkIn) {
      setFormError("Check-out must be later than check-in.");
      return;
    }
    if (guests > roomCapacities[roomType]) {
      setFormError(`This room accommodates up to ${roomCapacities[roomType]} guests.`);
      return;
    }
    const roomNumbers: Record<string, string> = { "Garden Queen": "216", "Deluxe King": "310", "Harbor Suite": "503" };
    const nights = Math.round((new Date(`${checkOut}T12:00:00`).getTime() - new Date(`${checkIn}T12:00:00`).getTime()) / 86_400_000);
    const record: Reservation = {
      id: `RS-${2049 + reservations.length - initialReservations.length}`,
      guest: `${firstName} ${lastName}`,
      email,
      phone,
      room: roomNumbers[roomType],
      roomType,
      checkIn,
      checkOut,
      guests,
      status: "pending",
      total: nights * roomRates[roomType as keyof typeof roomRates],
    };
    setReservations((current) => [record, ...current]);
    setShowModal(false);
    setFormError("");
    setNotice(`${record.id} created as pending.`);
    event.currentTarget.reset();
  }

  return (
    <main className="app-shell">
      <aside className={`sidebar ${mobileNav ? "sidebar-open" : ""}`}>
        <Link className="brand" href="/"><span className="brand-mark"><span /></span><span className="brand-copy"><strong>DB HOTEL MANAGEMENT</strong><small>OPERATIONS CONSOLE</small></span></Link>
        <div className="menu-anchor property-menu-anchor"><button className="property-switcher" aria-expanded={showPropertyMenu} aria-haspopup="menu" onClick={() => setShowPropertyMenu((open) => !open)}><span className="property-avatar">M</span><span><strong>Meridian House</strong><small>Portland, Oregon</small></span><ChevronDown size={15} /></button>{showPropertyMenu && <div className="dropdown-menu property-dropdown" role="menu"><p className="dropdown-heading">ACTIVE PROPERTY</p><button className="dropdown-choice selected-choice" role="menuitem" onClick={() => setShowPropertyMenu(false)}><span className="property-choice-dot" /><span><strong>Meridian House</strong><small>Portland, Oregon</small></span><Check size={15} /></button><Link href="/rooms" role="menuitem" className="dropdown-link" onClick={() => setShowPropertyMenu(false)}>View room inventory <ArrowRight size={14} /></Link><Link href="/billing" role="menuitem" className="dropdown-link" onClick={() => setShowPropertyMenu(false)}>Open billing <ArrowRight size={14} /></Link></div>}</div>
        <p className="nav-label">WORKSPACE</p>
        <nav className="main-nav" aria-label="Main navigation">{navigation.map(({ label, href, icon: Icon }) => <Link key={label} href={href} className={`nav-link ${activeNav === label ? "active" : ""}`} onClick={() => setMobileNav(false)}><Icon size={18} strokeWidth={1.8} /><span>{label}</span>{label === "Reservations" && <span className="nav-count">{reservations.length}</span>}</Link>)}</nav>
        <div className="sidebar-bottom"><div className="sidebar-note"><Sparkles size={16} /><span><strong>Today at a glance</strong><small>7 arrivals · 5 departures</small></span></div><button className="user-profile" aria-label="User profile"><span className="user-avatar">KD</span><span><strong>Kaphan David</strong><small>Hotel manager</small></span><span className="more-dots"><i /><i /><i /></span></button></div>
      </aside>
      {mobileNav && <button className="nav-scrim" onClick={() => setMobileNav(false)} aria-label="Close navigation" />}

      <section className="main-area" id="overview">
        <header className="topbar"><button className="icon-button mobile-menu" onClick={() => setMobileNav(true)} aria-label="Open navigation"><Menu size={19} /></button><div className="breadcrumbs"><span>Workspace</span><span className="crumb-separator">/</span><strong>{activeNav}</strong></div><div className="topbar-actions"><span className="live-indicator"><i /> Operations live</span><button className="avatar-small" aria-label="Kaphan David profile">KD</button></div></header>
        <div className="content-wrap">
          <motion.div
            key={activeNav}
            variants={staggerContainer}
            initial={reduceMotion ? false : "hidden"}
            animate="visible"
          >
          {activeSection ? <WorkspacePage section={activeSection} reservations={reservations} onNewReservation={() => setShowModal(true)} /> : <>
          <motion.section className="welcome-row" variants={revealItem}><div><p className="eyebrow">SATURDAY, OCTOBER 17, 2026 <span>·</span> PORTLAND, OR</p><h1>Good morning, Kaphan<span>.</span></h1><p className="welcome-subtitle">Here&apos;s what&apos;s happening at Meridian House today.</p></div><button className="primary-button" onClick={() => setShowModal(true)}><Plus size={17} /> New reservation</button></motion.section>
          {notice && <motion.div className="notice" variants={revealItem}><Check size={16} />{notice}<button aria-label="Dismiss notification" onClick={() => setNotice("")}><X size={15} /></button></motion.div>}

          <motion.section className="summary-grid" aria-label="Today's hotel metrics" variants={staggerContainer}>
            <motion.article className="summary-card occupancy-card" variants={revealItem}><div className="metric-top"><span>ROOM OCCUPANCY</span><span className="metric-icon"><BedDouble size={17} /></span></div><div className="metric-value">78<span className="metric-unit">%</span></div><div className="metric-foot"><div className="occupancy-track"><span /></div><span>62 of 80 rooms</span></div><span className="metric-caption">+6% from last week</span></motion.article>
            <motion.article className="summary-card" variants={revealItem}><div className="metric-top"><span>ARRIVALS TODAY</span><span className="metric-icon icon-sage"><ArrowDownToLine size={17} /></span></div><div className="metric-value">07</div><div className="metric-foot"><span className="metric-highlight">4 rooms ready</span><span>3 pending cleaning</span></div><span className="metric-caption">Next arrival · 10:30 AM</span></motion.article>
            <motion.article className="summary-card" variants={revealItem}><div className="metric-top"><span>DEPARTURES TODAY</span><span className="metric-icon icon-clay"><ArrowRight size={17} /></span></div><div className="metric-value">05</div><div className="metric-foot"><span className="metric-highlight">2 checked out</span><span>3 expected</span></div><span className="metric-caption">Latest checkout · 11:00 AM</span></motion.article>
            <motion.article className="summary-card" variants={revealItem}><div className="metric-top"><span>REVENUE TODAY</span><span className="metric-icon icon-gold"><CircleDollarSign size={17} /></span></div><div className="metric-value money-value">{money.format(428_000)}</div><div className="metric-foot"><span className="metric-highlight">68% collected</span><span>of {money.format(629_400)} due</span></div><span className="metric-caption">Across 18 active invoices</span></motion.article>
          </motion.section>

          <motion.section className="operations-grid" variants={staggerContainer}>
            <motion.div className="panel reservation-panel" variants={revealItem}>
              <div className="panel-heading"><div><p className="eyebrow">FRONT DESK</p><h2>Reservations</h2></div><button className="subtle-button" onClick={() => navigateTo("Reservations")}>View all <ArrowRight size={15} /></button></div>
              <div className="table-toolbar"><div className="filter-tabs" role="tablist" aria-label="Filter reservations">{[{ id: "all", label: "All stays" }, { id: "confirmed", label: "Confirmed" }, { id: "pending", label: "Pending" }].map((item) => <button key={item.id} role="tab" aria-selected={filter === item.id} className={filter === item.id ? "selected" : ""} onClick={() => setFilter(item.id as "all" | ReservationStatus)}>{item.label}</button>)}</div><label className="search-field"><Search size={15} /><input aria-label="Search reservations" placeholder="Search stays" value={search} onChange={(event) => setSearch(event.target.value)} /><kbd>/</kbd></label><button className={`toolbar-icon ${showReservationFilters ? "active-toolbar-icon" : ""}`} aria-label="More filters" aria-expanded={showReservationFilters} aria-haspopup="true" onClick={() => setShowReservationFilters((open) => !open)}><SlidersHorizontal size={16} /></button></div>
              {showReservationFilters && <div className="filter-panel" role="group" aria-label="Advanced reservation filters"><label>Status<select value={filter} onChange={(event) => setFilter(event.target.value as "all" | ReservationStatus)}><option value="all">All statuses</option><option value="confirmed">Confirmed</option><option value="pending">Pending</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select></label><label>Room type<select value={roomTypeFilter} onChange={(event) => setRoomTypeFilter(event.target.value)}><option value="all">All room types</option>{Array.from(new Set(reservations.map((reservation) => reservation.roomType))).map((roomType) => <option key={roomType} value={roomType}>{roomType}</option>)}</select></label><label>Sort by<select value={reservationSort} onChange={(event) => setReservationSort(event.target.value)}><option value="checkIn">Check-in date</option><option value="total-desc">Highest total</option><option value="total-asc">Lowest total</option></select></label><button className="filter-reset" onClick={() => { setFilter("all"); setRoomTypeFilter("all"); setReservationSort("checkIn"); setSearch(""); }}>Reset filters</button></div>}
              <div className="table-scroll"><table><thead><tr><th>GUEST</th><th>ROOM</th><th>STAY DATES</th><th>GUESTS</th><th>STATUS</th><th className="align-right">TOTAL</th></tr></thead><motion.tbody variants={staggerContainer}>{visibleReservations.length ? visibleReservations.map((reservation) => <motion.tr key={reservation.id} variants={revealItem}><td><span className="guest-name">{reservation.guest}</span><span className="guest-id">{reservation.id}</span></td><td><span className="room-number">{reservation.room}</span><span className="room-type">{reservation.roomType}</span></td><td><span>{formatDate(reservation.checkIn)} <span className="date-arrow">→</span> {formatDate(reservation.checkOut)}</span><span className="guest-id">{Math.round((new Date(`${reservation.checkOut}T12:00:00`).getTime() - new Date(`${reservation.checkIn}T12:00:00`).getTime()) / 86_400_000)} nights</span></td><td>{reservation.guests} {reservation.guests === 1 ? "guest" : "guests"}</td><td><span className={`status status-${reservation.status}`}><i />{reservation.status}</span></td><td className="align-right total-cell">{money.format(reservation.total)}</td></motion.tr>) : <tr><td colSpan={6} className="empty-state">No stays match this search.</td></tr>}</motion.tbody></table></div>
              <div className="table-footer"><span>Showing <strong>{visibleReservations.length}</strong> of <strong>{reservations.length}</strong> reservations</span><button onClick={() => navigateTo("Reservations")}>Open reservations <ArrowRight size={14} /></button></div>
            </motion.div>
            <motion.aside className="right-column" variants={revealItem}>
              <motion.section className="panel room-panel" variants={revealItem}><div className="panel-heading compact-heading"><div><p className="eyebrow">HOUSEKEEPING</p><h2>Room status</h2></div><div className="menu-anchor"><button className={`toolbar-icon ${showRoomStatusMenu ? "active-toolbar-icon" : ""}`} aria-label="Room status options" aria-expanded={showRoomStatusMenu} aria-haspopup="menu" onClick={() => setShowRoomStatusMenu((open) => !open)}><ChevronDown size={16} /></button>{showRoomStatusMenu && <div className="dropdown-menu status-dropdown" role="menu"><p className="dropdown-heading">FILTER ROOM STATUS</p><button className={`dropdown-option ${roomStatusFilter === "all" ? "dropdown-option-active" : ""}`} role="menuitemradio" aria-checked={roomStatusFilter === "all"} onClick={() => { setRoomStatusFilter("all"); setShowRoomStatusMenu(false); }}>All room statuses</button>{roomStatuses.map((status) => <button key={status.id} className={`dropdown-option ${roomStatusFilter === status.id ? "dropdown-option-active" : ""}`} role="menuitemradio" aria-checked={roomStatusFilter === status.id} onClick={() => { setRoomStatusFilter(status.id); setShowRoomStatusMenu(false); }}>{status.label}<span>{String(status.count).padStart(2, "0")}</span></button>)}</div>}</div></div><motion.div className="room-status-list" variants={staggerContainer}>{visibleRoomStatuses.map((status) => <motion.div className="room-status-row" key={status.id} variants={revealItem}><span className={`room-status-dot ${status.dot}`} /><span>{status.label}</span><strong>{String(status.count).padStart(2, "0")}</strong><div className={`tiny-bars ${status.bars}`}><i /><i /><i /><i /><i /></div></motion.div>)}</motion.div><button className="panel-link" onClick={() => navigateTo("Rooms")}>View floor plan <ArrowRight size={14} /></button></motion.section>
              <motion.section className="panel service-panel" variants={revealItem}><div className="panel-heading compact-heading"><div><p className="eyebrow">GUEST EXPERIENCE</p><h2>Upcoming services</h2></div><span className="service-date">TODAY</span></div><motion.div variants={staggerContainer}><motion.div className="service-item" variants={revealItem}><span className="service-symbol breakfast">B</span><div><strong>Breakfast for two</strong><small>Room 308 · 8:30 AM</small></div><span className="service-count">×1</span></motion.div><motion.div className="service-item" variants={revealItem}><span className="service-symbol spa">S</span><div><strong>Couples massage</strong><small>Room 501 · 2:00 PM</small></div><span className="service-count">×1</span></motion.div><motion.div className="service-item" variants={revealItem}><span className="service-symbol dining">D</span><div><strong>Harbor dining</strong><small>Room 214 · 7:00 PM</small></div><span className="service-count">×2</span></motion.div></motion.div><button className="panel-link" onClick={() => navigateTo("Services")}>Service schedule <ArrowRight size={14} /></button></motion.section>
            </motion.aside>
          </motion.section>
          <motion.section className="bottom-strip" variants={revealItem}><div className="strip-icon"><ClipboardList size={17} /></div><div><strong>3 invoices need attention</strong><span>Payments due for completed or active stays</span></div><button onClick={() => navigateTo("Billing")}>Review billing <ArrowRight size={14} /></button><span className="strip-divider" /><div className="strip-mini"><span>Pending payments</span><strong>{money.format(124_000)}</strong></div></motion.section>
          <motion.footer className="page-footer" variants={revealItem}><span>DB HOTEL MANAGEMENT <i>·</i> OPERATIONS CONSOLE</span><span>Database-aligned demo view <i>·</i> {today}</span></motion.footer>
          </>}
          </motion.div>
        </div>
      </section>

      {showModal && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setShowModal(false); }}><section className="reservation-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div className="modal-heading"><div><p className="eyebrow">FRONT DESK</p><h2 id="modal-title">New reservation</h2><p>Guest and stay details</p></div><button className="toolbar-icon" onClick={() => { setShowModal(false); setFormError(""); }} aria-label="Close reservation form"><X size={18} /></button></div><form onSubmit={createReservation}><div className="form-row"><label>First name<input name="firstName" autoComplete="given-name" required maxLength={80} /></label><label>Last name<input name="lastName" autoComplete="family-name" required maxLength={80} /></label></div><div className="form-row"><label>Email address<input name="email" type="email" autoComplete="email" required maxLength={254} /></label><label>Phone number<input name="phone" type="tel" autoComplete="tel" required maxLength={25} /></label></div><div className="form-row"><label>Check-in<input name="checkIn" type="date" min={today} defaultValue={today} required /></label><label>Check-out<input name="checkOut" type="date" min={today} required /></label></div><div className="form-row"><label>Room type<select name="roomType" value={selectedRoomType} onChange={(event) => setSelectedRoomType(event.target.value)}><option>Garden Queen</option><option>Deluxe King</option><option>Harbor Suite</option></select></label><label>Guests<input name="guests" type="number" min="1" max={roomCapacities[selectedRoomType]} defaultValue="1" required /></label></div>{formError && <p className="form-error" role="alert">{formError}</p>}<p className="form-hint">New reservations are created as pending. Room availability is confirmed by the front desk.</p><div className="modal-actions"><button type="button" className="secondary-button" onClick={() => setShowModal(false)}>Cancel</button><button type="submit" className="primary-button"><Plus size={16} /> Create reservation</button></div></form></section></div>}
    </main>
  );
}
