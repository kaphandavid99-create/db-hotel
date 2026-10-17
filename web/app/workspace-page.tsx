import {
  ArrowRight,
  BedDouble,
  CalendarDays,
  CircleDollarSign,
  ConciergeBell,
  Plus,
  Users,
} from "lucide-react";
import { motion } from "framer-motion";
import { roomRates } from "./pricing";
import { revealItem, staggerContainer } from "./motion";

export type ReservationRecord = {
  id: string;
  guest: string;
  email: string;
  phone: string;
  room: string;
  roomType: string;
  checkIn: string;
  checkOut: string;
  guests: number;
  status: "confirmed" | "pending" | "completed" | "cancelled";
  total: number;
};

export type WorkspaceSection = "Reservations" | "Rooms" | "Guests" | "Services" | "Billing";

const money = new Intl.NumberFormat("fr-FR", {
  style: "currency",
  currency: "XAF",
  maximumFractionDigits: 0,
});

const rooms = [
  { number: "116", floor: 1, type: "Courtyard Twin", capacity: 2, price: roomRates["Courtyard Twin"], status: "occupied" },
  { number: "214", floor: 2, type: "Garden Queen", capacity: 2, price: roomRates["Garden Queen"], status: "available" },
  { number: "308", floor: 3, type: "Deluxe King", capacity: 2, price: roomRates["Deluxe King"], status: "occupied" },
  { number: "402", floor: 4, type: "Deluxe King", capacity: 2, price: roomRates["Deluxe King"], status: "being_cleaned" },
  { number: "501", floor: 5, type: "Harbor Suite", capacity: 4, price: roomRates["Harbor Suite"], status: "occupied" },
  { number: "503", floor: 5, type: "Harbor Suite", capacity: 4, price: roomRates["Harbor Suite"], status: "out_of_service" },
];

const services = [
  { name: "Breakfast service", description: "In-room breakfast delivery", price: 12_000, capacity: 18, bookings: 6 },
  { name: "Couples massage", description: "60-minute spa appointment", price: 75_000, capacity: 4, bookings: 2 },
  { name: "Harbor dining", description: "Private dining reservation", price: 45_000, capacity: 12, bookings: 5 },
  { name: "Airport transfer", description: "One-way private transfer", price: 35_000, capacity: 8, bookings: 3 },
];

function date(value: string) {
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric" }).format(new Date(`${value}T12:00:00`));
}

function PageHeading({ section, onNewReservation }: { section: WorkspaceSection; onNewReservation: () => void }) {
  const heading: Record<WorkspaceSection, { eyebrow: string; title: string; description: string; Icon: typeof CalendarDays }> = {
    Reservations: { eyebrow: "FRONT DESK", title: "Reservations", description: "Manage stays, dates, guests, and reservation status.", Icon: CalendarDays },
    Rooms: { eyebrow: "HOUSEKEEPING", title: "Rooms", description: "Room inventory, capacity, nightly rates, and operational status.", Icon: BedDouble },
    Guests: { eyebrow: "CLIENT DIRECTORY", title: "Guests", description: "Client contact details and reservation history.", Icon: Users },
    Services: { eyebrow: "GUEST EXPERIENCE", title: "Services", description: "Service catalog, prices, capacity, and today's bookings.", Icon: ConciergeBell },
    Billing: { eyebrow: "ACCOUNTS", title: "Billing", description: "Invoice status and reservation balances.", Icon: CircleDollarSign },
  };
  const { eyebrow, title, description, Icon } = heading[section];

  return (
      <motion.header className="workspace-page-heading" variants={revealItem}>
        <div className="workspace-title-group">
          <span className="workspace-title-icon"><Icon size={19} /></span>
          <div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p>{description}</p></div>
        </div>
        {section === "Reservations" && <button className="primary-button" onClick={onNewReservation}><Plus size={17} /> New reservation</button>}
      </motion.header>
  );
}

function WorkspaceContent({ section, reservations, onNewReservation }: { section: WorkspaceSection; reservations: ReservationRecord[]; onNewReservation: () => void }) {
  if (section === "Reservations") {
    return (
      <motion.section className="panel workspace-table-panel" variants={revealItem}>
        <div className="workspace-panel-heading"><div><p className="eyebrow">STAYS</p><h2>All reservations</h2></div><span className="workspace-record-count">{reservations.length} records</span></div>
        <div className="table-scroll"><table><thead><tr><th>RESERVATION</th><th>GUEST</th><th>ROOM</th><th>CHECK-IN</th><th>CHECK-OUT</th><th>GUESTS</th><th>STATUS</th><th className="align-right">TOTAL</th></tr></thead><motion.tbody variants={staggerContainer}>
          {reservations.map((reservation) => <motion.tr key={reservation.id} variants={revealItem}><td className="workspace-strong">{reservation.id}</td><td><span className="guest-name">{reservation.guest}</span><span className="guest-id">{reservation.email}</span></td><td>{reservation.room} <span className="room-type inline-room-type">{reservation.roomType}</span></td><td>{date(reservation.checkIn)}</td><td>{date(reservation.checkOut)}</td><td>{reservation.guests}</td><td><span className={`status status-${reservation.status}`}><i />{reservation.status}</span></td><td className="align-right total-cell">{money.format(reservation.total)}</td></motion.tr>)}
        </motion.tbody></table></div>
        <div className="workspace-table-footer"><span>Reservation status follows the database values.</span><button onClick={onNewReservation}>Create a reservation <ArrowRight size={14} /></button></div>
      </motion.section>
    );
  }

  if (section === "Rooms") {
    const count = (status: string) => rooms.filter((room) => room.status === status).length;
    return <>
      <motion.div className="workspace-stat-grid" variants={staggerContainer}><Stat label="Total listed" value={String(rooms.length).padStart(2, "0")} detail="rooms in inventory" /><Stat label="Available" value={String(count("available")).padStart(2, "0")} detail="ready to assign" /><Stat label="Occupied" value={String(count("occupied")).padStart(2, "0")} detail="currently in use" /><Stat label="Unavailable" value={String(count("being_cleaned") + count("out_of_service")).padStart(2, "0")} detail="cleaning or out of service" /></motion.div>
      <motion.section className="panel workspace-table-panel" variants={revealItem}><div className="workspace-panel-heading"><div><p className="eyebrow">ROOM INVENTORY</p><h2>Room status</h2></div><span className="workspace-record-count">Operational status</span></div><div className="table-scroll"><table><thead><tr><th>ROOM</th><th>FLOOR</th><th>ROOM TYPE</th><th>CAPACITY</th><th>BASE PRICE / NIGHT</th><th>OPERATIONAL STATUS</th></tr></thead><motion.tbody variants={staggerContainer}>{rooms.map((room) => <motion.tr key={room.number} variants={revealItem}><td className="workspace-strong">{room.number}</td><td>{room.floor}</td><td>{room.type}</td><td>{room.capacity} guests</td><td className="total-cell">{money.format(room.price)}</td><td><span className={`status status-room-${room.status}`}><i />{room.status.replaceAll("_", " ")}</span></td></motion.tr>)}</motion.tbody></table></div></motion.section>
    </>;
  }

  if (section === "Guests") {
    const guests = reservations.map((reservation) => ({ ...reservation, lastName: reservation.guest.split(" ").at(-1) ?? reservation.guest, firstName: reservation.guest.split(" ")[0] }));
    return <motion.section className="panel workspace-table-panel" variants={revealItem}><div className="workspace-panel-heading"><div><p className="eyebrow">CLIENTS</p><h2>Guest directory</h2></div><span className="workspace-record-count">{guests.length} clients</span></div><div className="table-scroll"><table><thead><tr><th>FIRST NAME</th><th>LAST NAME</th><th>EMAIL</th><th>PHONE</th><th>RESERVATION</th><th>STAY</th></tr></thead><motion.tbody variants={staggerContainer}>{guests.map((guest) => <motion.tr key={guest.email} variants={revealItem}><td className="workspace-strong">{guest.firstName}</td><td>{guest.lastName}</td><td>{guest.email}</td><td>{guest.phone}</td><td>{guest.id}</td><td>{date(guest.checkIn)} – {date(guest.checkOut)}</td></motion.tr>)}</motion.tbody></table></div></motion.section>;
  }
  if (section === "Services") {
    return <>
      <motion.div className="workspace-stat-grid" variants={staggerContainer}><Stat label="Services" value={String(services.length).padStart(2, "0")} detail="active in catalog" /><Stat label="Today's bookings" value="16" detail="across all services" /><Stat label="Open slots" value="16" detail="remaining today" /><Stat label="Upcoming" value="03" detail="next service appointments" /></motion.div>
      <motion.section className="panel workspace-table-panel" variants={revealItem}><div className="workspace-panel-heading"><div><p className="eyebrow">SERVICE CATALOG</p><h2>Services and bookings</h2></div><span className="workspace-record-count">Price and slot capacity</span></div><div className="table-scroll"><table><thead><tr><th>SERVICE</th><th>DESCRIPTION</th><th>PRICE</th><th>SLOT CAPACITY</th><th>BOOKED TODAY</th><th>OPEN SLOTS</th></tr></thead><motion.tbody variants={staggerContainer}>{services.map((service) => <motion.tr key={service.name} variants={revealItem}><td className="workspace-strong">{service.name}</td><td>{service.description}</td><td className="total-cell">{money.format(service.price)}</td><td>{service.capacity}</td><td>{service.bookings}</td><td>{service.capacity - service.bookings}</td></motion.tr>)}</motion.tbody></table></div></motion.section>
      <motion.section className="panel upcoming-panel" variants={revealItem}><div className="workspace-panel-heading"><div><p className="eyebrow">TODAY</p><h2>Upcoming service bookings</h2></div><span className="workspace-record-count">3 appointments</span></div><motion.div variants={staggerContainer}><motion.div className="upcoming-booking" variants={revealItem}><strong>Breakfast service</strong><span>Room 308 · 8:30 AM</span><span className="service-count">×1</span></motion.div><motion.div className="upcoming-booking" variants={revealItem}><strong>Couples massage</strong><span>Room 501 · 2:00 PM</span><span className="service-count">×1</span></motion.div><motion.div className="upcoming-booking" variants={revealItem}><strong>Harbor dining</strong><span>Room 214 · 7:00 PM</span><span className="service-count">×2</span></motion.div></motion.div></motion.section>
    </>;
  }

  const invoices = reservations.slice(0, 4).map((reservation, index) => ({ ...reservation, invoiceId: `INV-${3108 - index}`, status: index === 2 ? "due" : index === 1 ? "partially_paid" : "paid", paid: index === 2 ? 0 : index === 1 ? Math.round(reservation.total / 2) : reservation.total }));
  return <>
    <motion.div className="workspace-stat-grid" variants={staggerContainer}><Stat label="Collected today" value={money.format(428_000)} detail="payments recorded" /><Stat label="Outstanding" value={money.format(124_000)} detail="across due invoices" /><Stat label="Invoices due" value="03" detail="need attention" /><Stat label="Payment methods" value="04" detail="cash, card, mobile, bank" /></motion.div>
    <motion.section className="panel workspace-table-panel" variants={revealItem}><div className="workspace-panel-heading"><div><p className="eyebrow">INVOICES</p><h2>Reservation billing</h2></div><span className="workspace-record-count">One invoice per reservation</span></div><div className="table-scroll"><table><thead><tr><th>INVOICE</th><th>RESERVATION</th><th>CLIENT</th><th>ISSUED</th><th>STATUS</th><th>PAID</th><th className="align-right">TOTAL DUE</th></tr></thead><motion.tbody variants={staggerContainer}>{invoices.map((invoice) => <motion.tr key={invoice.invoiceId} variants={revealItem}><td className="workspace-strong">{invoice.invoiceId}</td><td>{invoice.id}</td><td>{invoice.guest}</td><td>{date(invoice.checkIn)}</td><td><span className={`status status-invoice-${invoice.status}`}><i />{invoice.status.replaceAll("_", " ")}</span></td><td>{money.format(invoice.paid)}</td><td className="align-right total-cell">{money.format(invoice.total)}</td></motion.tr>)}</motion.tbody></table></div><div className="workspace-table-footer"><span>Payments support cash, card, mobile money, and bank transfer.</span><span className="workspace-strong">Balances shown in FCFA</span></div></motion.section>
  </>;
}

function Stat({ label, value, detail }: { label: string; value: string; detail: string }) {
  return <motion.article className="workspace-stat" variants={revealItem}><span>{label}</span><strong>{value}</strong><small>{detail}</small></motion.article>;
}

export default function WorkspacePage({ section, reservations, onNewReservation }: { section: WorkspaceSection; reservations: ReservationRecord[]; onNewReservation: () => void }) {
  return <motion.section className="workspace-page" variants={staggerContainer}><PageHeading section={section} onNewReservation={onNewReservation} /><WorkspaceContent section={section} reservations={reservations} onNewReservation={onNewReservation} /></motion.section>;
}