# Mac Screensaver Design

## Goal

Create a Mac screensaver for Overhead Tracker that feels like a live aircraft readout, not a generic animated wallpaper. It should surface real nearby flight data from the existing proxy and present one aircraft at a time in a rotating, full-screen card.

## Product Shape

This is a data-first screensaver with no map. It is intentionally simpler than the web app and should be optimized for glanceability, legibility, and low distraction.

The screensaver should:
- Show live aircraft data from the existing proxy
- Rotate through nearby flights one at a time
- Sort flights by closest first
- Use a balanced rotation interval of 10 seconds per card
- Fail clearly when offline or when no flights are available

## Core Screen

The main screen is a single centered flight card on a dark background.

Card content, top to bottom:
- Callsign
- Airline
- Route city pair
- Aircraft type and registration
- Altitude, speed, distance, and phase

The hierarchy is the point:
- Callsign is the largest text
- Route is the next strongest line
- Supporting data stays smaller and compact
- Phase drives the accent color

## Visual Direction

The design should feel like a high-end ops display.

Rules:
- Dark background
- Strong typography
- Minimal decoration
- Subtle motion only
- No map
- No chart junk
- No fake aviation wallpaper treatment

Motion should be limited to small transitions such as fades or short slides between cards. Any animation should support readability, not compete with it.

## Rotation Rules

When multiple aircraft are available:
- Sort by distance ascending
- Show the closest aircraft first
- Rotate through the rest in that order
- Hold each card for 10 seconds

If a flight is clearly more urgent because of a warning state, it may be visually emphasized, but the sort order stays closest-first for now. That keeps the behavior predictable and easy to scan.

## States

The screensaver needs clear states so it never looks broken.

### Loading
- Show a simple loading state while data is being fetched
- Do not leave the screen blank

### Live Flight
- Show the rotating flight card with live data
- Accent color reflects the flight phase

### No Flights
- Show a blunt "no aircraft overhead" style state
- Keep the same visual language so it still feels intentional

### Offline
- Show that live data is unavailable
- Keep retrying in the background
- Do not pretend stale data is current

### Emergency
- Use a red override for emergency squawks
- Emergency state takes precedence over normal phase coloring

## Data Contract

The screensaver should reuse the project's existing flight concepts instead of inventing new ones.

Expected fields:
- Callsign
- Airline name or brand
- Aircraft type
- Registration
- Origin city and destination city
- Altitude
- Speed
- Distance
- Flight phase
- Squawk or warning state when present

If a field is missing, the layout should degrade cleanly rather than leaving holes or shifting unpredictably.

## Interaction

The screensaver is passive.

It should not require user input beyond standard screensaver activation and exit behavior. There is no map interaction, filtering, or manual flight selection.

## Out of Scope

Not included in this design:
- Live map rendering
- Flight-path trails
- User-configurable filters inside the screensaver
- Interactive flight selection
- Generic photo or wallpaper backgrounds
- A separate “dashboard” mode with multiple panels

## Success Criteria

The design is successful if:
- It reads clearly from a normal Mac viewing distance
- It feels directly tied to Overhead Tracker
- It stays useful even with only a few aircraft
- It degrades cleanly with no flights or no network
- It does not look like a stock screensaver preset
