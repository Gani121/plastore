import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// No description provided for @addMoreItems.
  ///
  /// In en, this message translates to:
  /// **'ADD MORE ITEMS'**
  String get addMoreItems;

  /// No description provided for @billItems.
  ///
  /// In en, this message translates to:
  /// **'BILL ITEMS'**
  String get billItems;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer/Supplier Name'**
  String get customerName;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get total;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @dashbord.
  ///
  /// In en, this message translates to:
  /// **'Dashbord'**
  String get dashbord;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get setting;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @sales_report.
  ///
  /// In en, this message translates to:
  /// **'Sales Report'**
  String get sales_report;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @recentSell.
  ///
  /// In en, this message translates to:
  /// **'RECENT SALE TRANSACTIONS'**
  String get recentSell;

  /// No description provided for @totalTransection.
  ///
  /// In en, this message translates to:
  /// **'Total Transactions'**
  String get totalTransection;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @billNo.
  ///
  /// In en, this message translates to:
  /// **'Bill No'**
  String get billNo;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @settle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get settle;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @sale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get sale;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @saleFor.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get saleFor;

  /// No description provided for @party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get party;

  /// No description provided for @udhari.
  ///
  /// In en, this message translates to:
  /// **'Udhari'**
  String get udhari;

  /// No description provided for @inventoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryLabel;

  /// No description provided for @tables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get tables;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get searchItems;

  /// No description provided for @itemList.
  ///
  /// In en, this message translates to:
  /// **'Item List'**
  String get itemList;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'Current Stock'**
  String get currentStock;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stock'**
  String get adjustStock;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'NEW ITEM'**
  String get newItem;

  /// No description provided for @noItemMatch.
  ///
  /// In en, this message translates to:
  /// **'No items match your search.'**
  String get noItemMatch;

  /// No description provided for @noItemFound.
  ///
  /// In en, this message translates to:
  /// **'No items found. Add some items to get started!'**
  String get noItemFound;

  /// No description provided for @inventoryHeader.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY'**
  String get inventoryHeader;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @stockUpdatedTo.
  ///
  /// In en, this message translates to:
  /// **'Stock updated to'**
  String get stockUpdatedTo;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enterQuantityAdd.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity to add'**
  String get enterQuantityAdd;

  /// No description provided for @adjustStockFor.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stock for'**
  String get adjustStockFor;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get deleteNote;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteItemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Item deleted successfully'**
  String get deleteItemSuccess;

  /// No description provided for @businessDateChanged.
  ///
  /// In en, this message translates to:
  /// **'Business date changed'**
  String get businessDateChanged;

  /// No description provided for @exit_App.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exit_App;

  /// No description provided for @exit_sms.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get exit_sms;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @loding.
  ///
  /// In en, this message translates to:
  /// **'Loding'**
  String get loding;

  /// No description provided for @edit_trans.
  ///
  /// In en, this message translates to:
  /// **'Choose an action for this transaction.'**
  String get edit_trans;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @enter_qty_add.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity to add'**
  String get enter_qty_add;

  /// No description provided for @enter_valid_number.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enter_valid_number;

  /// No description provided for @recent_tran.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recent_tran;

  /// No description provided for @access_denied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get access_denied;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
