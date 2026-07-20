# PHD Software — Website

A single-page marketing site for **PHD Software** ([phdsoftware.com](https://phdsoftware.com)),
a UAE-based high-tech studio in Mirdif (105), Dubai, that builds software, games,
and mobile applications. The portfolio section lists our shipped products:
Habitron Scan, convertorpdf, Dubai Talents, Emberdate, Only Paw, onlypaws, and VPN Panda.

## Stack

- Plain HTML, CSS, and vanilla JavaScript — no build step, no dependencies.
- Space Grotesk + Inter from Google Fonts.
- Responsive down to phone widths; respects `prefers-reduced-motion`.

## Structure

```
index.html   — page markup
styles.css   — theme, layout, components
app.js       — mobile nav, contact form, footer year
```

## Run locally

Open `index.html` directly in a browser, or serve the folder:

```bash
python3 -m http.server 8000
```

Then visit http://localhost:8000.
