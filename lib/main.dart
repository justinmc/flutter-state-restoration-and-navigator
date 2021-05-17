import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(RootRestorationScope(
    child: BooksApp(),
    restorationId: 'root',
  ));
}

class Book {
  final String title;
  final String author;

  Book(this.title, this.author);
}

class BooksApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _BooksAppState();
}

class _BooksAppState extends State<BooksApp> with RestorationMixin {
  RestorableBookDelegate _routerDelegate = RestorableBookDelegate();
  BookRouteInformationParser _routeInformationParser =
      BookRouteInformationParser();

  @override
  String? get restorationId => 'app';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_routerDelegate, 'delegate');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Books App',
      routerDelegate: _routerDelegate.value,
      routeInformationParser: _routeInformationParser,
      restorationScopeId: 'materialapp',
    );
  }
}

class BookRouteInformationParser extends RouteInformationParser<BookRoutePath> {
  @override
  Future<BookRoutePath> parseRouteInformation(
      RouteInformation routeInformation) {
    final uri = Uri.parse(routeInformation.location!);

    if (uri.pathSegments.length >= 2) {
      var remaining = uri.pathSegments[1];
      return SynchronousFuture(BookRoutePath.details(int.tryParse(remaining)!));
    } else {
      return SynchronousFuture(BookRoutePath.home());
    }
  }

  @override
  RouteInformation restoreRouteInformation(BookRoutePath path) {
    if (path.isHomePage) {
      return RouteInformation(location: '/');
    }
    if (path.isDetailsPage) {
      return RouteInformation(location: '/book/${path.id}');
    }
    return RouteInformation(location: '/404');
  }
}

class BookRouterDelegate extends RouterDelegate<BookRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<BookRoutePath> {
  final GlobalKey<NavigatorState> navigatorKey;

  Book? _selectedBook;

  // TODO: Instead of translating everywhere between id and Book just store it internally as id?
  int? get selectedBook =>
      _selectedBook != null ? books.indexOf(_selectedBook!) : null;

  static List<Book> books = [
    Book('Stranger in a Strange Land', 'Robert A. Heinlein'),
    Book('Foundation', 'Isaac Asimov'),
    Book('Fahrenheit 451', 'Ray Bradbury'),
  ];

  BookRouterDelegate({int? selectedBook})
      : navigatorKey = GlobalKey<NavigatorState>(),
        _selectedBook = selectedBook != null ? books[selectedBook] : null;

  BookRoutePath get currentConfiguration => _selectedBook == null
      ? BookRoutePath.home()
      : BookRoutePath.details(books.indexOf(_selectedBook!));

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      restorationScopeId: 'navigator',
      transitionDelegate: NoAnimationTransitionDelegate(),
      pages: [
        MaterialPage(
          key: ValueKey('BooksListPage'),
          restorationId: 'book-list-page',
          child: BooksListScreen(
            books: books,
            onTapped: _handleBookTapped,
          ),
        ),
        if (_selectedBook != null) BookDetailsPage(book: _selectedBook!)
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }

        // Update the list of pages by setting _selectedBook to null
        _selectedBook = null;
        notifyListeners();

        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(BookRoutePath path) {
    if (path.isDetailsPage) {
      _selectedBook = books[path.id!];
    }
    return SynchronousFuture<void>(null);
  }

  void _handleBookTapped(Book book) {
    _selectedBook = book;
    notifyListeners();
  }
}

class BookDetailsPage extends Page {
  final Book book;

  BookDetailsPage({
    required this.book,
  }) : super(key: ValueKey(book));

  @override
  final String restorationId = 'book-details-page';

  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (BuildContext context) {
        return BookDetailsScreen(book: book);
      },
    );
  }
}

class BookRoutePath {
  final int? id;

  BookRoutePath.home() : id = null;

  BookRoutePath.details(this.id);

  bool get isHomePage => id == null;

  bool get isDetailsPage => id != null;

  @override
  String toString() => 'BookRoutePath(${isHomePage ? 'home' : 'details: $id'})';
}

class BooksListScreen extends StatelessWidget {
  final List<Book> books;
  final ValueChanged<Book> onTapped;

  BooksListScreen({
    required this.books,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          for (var book in books)
            ListTile(
              title: Text(book.title),
              subtitle: Text(book.author),
              onTap: () => onTapped(book),
            )
        ],
      ),
    );
  }
}

class BookDetailsScreen extends StatelessWidget {
  final Book? book;

  BookDetailsScreen({
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book != null) ...[
              Text(book!.title, style: Theme.of(context).textTheme.headline6),
              Text(book!.author, style: Theme.of(context).textTheme.subtitle1),
            ],
          ],
        ),
      ),
    );
  }
}

class NoAnimationTransitionDelegate extends TransitionDelegate<void> {
  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  }) {
    final results = <RouteTransitionRecord>[];

    for (final pageRoute in newPageRouteHistory) {
      if (pageRoute.isWaitingForEnteringDecision) {
        pageRoute.markForAdd();
      }
      results.add(pageRoute);
    }

    for (final exitingPageRoute in locationToExitingPageRoute.values) {
      if (exitingPageRoute.isWaitingForExitingDecision) {
        exitingPageRoute.markForRemove();
        final pagelessRoutes = pageRouteToPagelessRoutes[exitingPageRoute];
        if (pagelessRoutes != null) {
          for (final pagelessRoute in pagelessRoutes) {
            pagelessRoute.markForRemove();
          }
        }
      }

      results.add(exitingPageRoute);
    }
    return results;
  }
}

class RestorableBookDelegate
    extends RestorableChangeNotifier<BookRouterDelegate> {
  @override
  BookRouterDelegate createDefaultValue() => BookRouterDelegate();

  @override
  BookRouterDelegate fromPrimitives(Object? data) =>
      BookRouterDelegate(selectedBook: data as int?);

  @override
  Object? toPrimitives() => value.selectedBook;
}
