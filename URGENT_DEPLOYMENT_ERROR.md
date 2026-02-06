# URGENT: Deployment Build Failure & Handover Notes

## Summary
The premium UI updates for the Customer Menu, Cart, and Payment flows have been fully implemented and verified working locally (`flutter run -d chrome` at port 9904). However, the **Production Build is Failing**, which prevents deployment to Firebase Hosting.

## Current Status
- **UI Completed:**
  - `MenuPage`: Added Search, Category Filters, Premium Header, and new `ProductCard`.
  - `CartPage`: Added Item Notes input, improved layout.
  - `Payment Pages`: Updated `PaymentMethodSelectorPage`, `PaymentCashPage`, and `PaymentQRISPage`.
- **Local Server:** Functional.
- **Production Build:** **BROKEN**.

## The Error
When running `flutter build web --release`, the process fails.
- **Log Fragment:** `...able.dart:103:` (The log was truncated in the previous session).
- **Flutter Analyze:** ~134 issues found (mostly "unused import"), but likely not the cause of the build failure unless treated as fatal.

## Suspected Causes
1.  **Compiler Difference:** `dart2js` (release compiler) is stricter than `dartdevc` (dev compiler). A type error or null safety issue might be present.
2.  **Recent Edits:** The error likely resides in one of the recently modified files:
    - `lib/features/customer/presentation/pages/menu_page.dart`
    - `lib/features/customer/presentation/pages/payment_cash_page.dart`
    - `lib/features/customer/presentation/pages/payment_qris_page.dart`
    - `lib/features/customer/presentation/menu_page.dart`

## Action Plan for Next AI
1.  **Get Full Log:** Run the following command to see the specific error line (do not trust truncated logs):
    ```bash
    flutter build web --release -v
    ```
2.  **Identify File:** Look for the file ending in `...able.dart` at line 103 (or the actual error reported by verbose mode). It could be a framework file (like `editable.dart`, `scrollable.dart`) complaining about a wrong parameter passed from our code.
3.  **Fix & Build:** Correct the code and ensure `flutter build web --release` completes successfully (creating `build/web` directory).
4.  **Deploy:** Run `firebase deploy` to update the live site.
