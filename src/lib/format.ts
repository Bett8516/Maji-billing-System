export const kes = (amount: number) => new Intl.NumberFormat("en-KE", { style: "currency", currency: "KES", maximumFractionDigits: 0 }).format(amount);
export const monthLabel = (value: string) => new Intl.DateTimeFormat("en", { month: "long", year: "numeric", timeZone: "Africa/Nairobi" }).format(new Date(`${value.slice(0,7)}-01T00:00:00+03:00`));
export const todayKenya = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Nairobi" }).format(new Date());
export const dateKenya = (value:string) => new Intl.DateTimeFormat("en-KE", { dateStyle:"medium", timeZone:"Africa/Nairobi" }).format(new Date(value));
