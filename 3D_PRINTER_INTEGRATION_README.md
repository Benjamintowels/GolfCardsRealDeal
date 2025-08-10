### 3D Printer → Printed Card → In-Run Deck: Integration Notes

- **Queue location (persistence)**
  - Printed cards are queued in `SaveFileManager.gd` under `clubhouse_progression.printed_cards_queue`.
  - The queue is populated in `UI/PrinterDialog.gd` via `SaveFileManager.queue_printed_card(card_path)`.

- **Printer dialog rules**
  - Print cost is 25 $Looty. It spends from ClubHouse first (`ClubHouseUpgradeManager.spend_clubhouse_looty(25)`); if insufficient, it falls back to player `Global.spend_looty(25)`.
  - The dialog shows both balances (ClubHouse and player) and enables Print if either can cover 25.
  - The gene list auto-selects the first item if nothing is selected.

- **When the card actually enters the run**
  - Decks are initialized/reset by `CurrentDeckManager.gd` (starter/fighter). This no longer clears the printed queue.
  - On course load, after deck sync, `course_1.gd` calls, in order:
    - `deck_manager.sync_with_current_deck()`
    - `deck_manager.inject_printed_cards_from_queue()`

- **How injection is done (single source of truth + piles)**
  - `DeckManager.gd` loads each queued card path, then:
    - Appends it to the correct pile: `action_draw_pile` for actions; `club_draw_pile` for clubs (`is_club_card()`).
    - Rebuilds/shuffles the respective deck order and resets the deck index.
    - Also calls `CurrentDeckManager.add_card_to_deck(card)` so future syncs keep the card.
    - Clears the printed queue (one-time bring) and emits `deck_updated`.

- **Guaranteeing opening hand (optional)**
  - If a printed card must appear immediately, call `DeckManager.insert_card_at_top_of_action_deck(card)` instead of shuffling it in.

- **One-liners to remember**
  - Queue is written in the clubhouse; consumed right after deck sync in the course.
  - ClubHouse wallet is tried first; player wallet is a fallback.
  - Printed cards are one-time per print; persistence across syncs is ensured by also updating `CurrentDeckManager`.

- **Key files/functions**
  - `UI/PrinterDialog.gd`: `_on_print_pressed`, `_update_print_button_state`, `_refresh`
  - `SaveFileManager.gd`: `queue_printed_card`, `get_printed_cards_queue`, `clear_printed_cards_queue`
  - `DeckManager.gd`: `sync_with_current_deck`, `inject_printed_cards_from_queue`, `is_club_card`, `insert_card_at_top_of_action_deck` (optional)
  - `current_deck_manager.gd`: `initialize_starter_deck`, `initialize_fighter_deck`
  - `course_1.gd`: after `sync_with_current_deck()`, call `inject_printed_cards_from_queue()`


