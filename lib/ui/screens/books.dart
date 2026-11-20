import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/books.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';

String _count(int n) => n.toString().replaceAllMapped(RegExp(r'\d'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);

/// الكتب: مكتبة christianlib.com بتخصصاتها، وبحث، وكتبي المنزّلة.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.onBack, required this.onOpenCategory, required this.onOpenBook});
  final VoidCallback onBack;
  final ValueChanged<BookCategory> onOpenCategory;
  final ValueChanged<LibraryBook> onOpenBook;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final repo = BooksRepository.instance;
  late Future<List<BookCategory>> _cats = repo.categories();
  String _q = '';
  Timer? _debounce;
  Future<BookPage>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _q = v.trim();
        _results = _q.length < 2 ? null : repo.books(search: _q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, pad.top, 16, pad.bottom + 24),
      children: [
        ScreenHeader('الكتب', subtitle: 'مكتبة الكتب المسيحية', onBack: widget.onBack),
        AppSearchBar(placeholder: 'ابحث عن كتاب أو مؤلف', onChanged: _search),
        const SizedBox(height: 16),
        if (_results != null)
          _ResultList(future: _results!, query: _q, onOpenBook: widget.onOpenBook)
        else ...[
          ListenableBuilder(
            listenable: repo,
            builder: (context, _) {
              final saved = repo.saved;
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('كتبي', style: context.heading(size: 18)),
                const SizedBox(height: 4),
                Text('متنزّلة على الموبايل، بتتقري من غير نت', style: TextStyle(fontSize: 12, color: c.textFaint)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: saved.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _ShelfBook(book: saved[i], onTap: () => widget.onOpenBook(saved[i])),
                  ),
                ),
                const SizedBox(height: 24),
              ]);
            },
          ),
          Text('التخصصات', style: context.heading(size: 18)),
          const SizedBox(height: 8),
          FutureBuilder<List<BookCategory>>(
            future: _cats,
            builder: (context, snap) {
              if (snap.hasError) {
                return _Retry(onRetry: () => setState(() => _cats = repo.categories()));
              }
              final all = snap.data;
              if (all == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              final top = all.where((x) => x.parent == 0).toList();
              return Column(children: [
                for (final cat in top)
                  _CategoryRow(
                    cat: cat,
                    subs: all.where((x) => x.parent == cat.id).length,
                    onTap: () => widget.onOpenCategory(cat),
                  ),
              ]);
            },
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.cat, required this.subs, required this.onTap});
  final BookCategory cat;
  final int subs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 60,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          AppIconView(AppIcon.books, size: 20, color: c.textSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name, style: TextStyle(fontSize: 16, color: c.text)),
              Text(subs > 0 ? '${_count(cat.count)} كتاب · ${_count(subs)} أقسام' : '${_count(cat.count)} كتاب',
                  style: TextStyle(fontSize: 12, color: c.textFaint)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textFaint),
        ]),
      ),
    );
  }
}

/// غلاف الكتاب، ولو مالوش صورة: لوح بلون الورق عليه أول كلمتين من العنوان.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, required this.width, required this.height});
  final LibraryBook book;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final blank = Container(
      color: c.chip,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(book.title, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(fontSize: width > 80 ? 13 : 9, color: c.textSoft, height: 1.3)),
    );
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.hairline),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? .3 : .08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: book.cover == null
          ? blank
          : CachedNetworkImage(
              imageUrl: book.cover!,
              httpHeaders: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36'},
              fit: BoxFit.cover,
              memCacheWidth: (width * 3).round(),
              placeholder: (_, __) => Container(color: c.chip),
              errorWidget: (_, __, ___) => blank,
            ),
    );
  }
}

class _ShelfBook extends StatelessWidget {
  const _ShelfBook({required this.book, required this.onTap});
  final LibraryBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BookCover(book: book, width: 96, height: 128),
          const SizedBox(height: 6),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.text, height: 1.3)),
        ]),
      ),
    );
  }
}

class BookRow extends StatelessWidget {
  const BookRow({super.key, required this.book, required this.onTap});
  final LibraryBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BookCover(book: book, width: 56, height: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: c.text, height: 1.4)),
              if (book.author != null) ...[
                const SizedBox(height: 2),
                Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSoft)),
              ],
              const SizedBox(height: 4),
              if (book.pdf == null)
                Text('من غير ملف تحميل', style: TextStyle(fontSize: 11, color: c.textFaint))
              else if (BooksRepository.instance.isSaved(book))
                Text('متنزّل', style: TextStyle(fontSize: 11, color: c.navGlow)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Text('تعذّر الاتصال بالمكتبة، تأكد من الاتصال بالإنترنت', textAlign: TextAlign.center, style: TextStyle(color: c.textSoft)),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text('حاول تاني', style: TextStyle(color: c.live))),
      ]),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.future, required this.query, required this.onOpenBook});
  final Future<BookPage> future;
  final String query;
  final ValueChanged<LibraryBook> onOpenBook;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<BookPage>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Text('تعذّر البحث، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft));
        final page = snap.data;
        if (page == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
        if (page.books.isEmpty) return Text('مافيش كتب لـ «$query»', style: TextStyle(color: c.textSoft));
        return Column(children: [for (final b in page.books) BookRow(book: b, onTap: () => onOpenBook(b))]);
      },
    );
  }
}

/// تخصص: أقسامه الفرعية كشرايح فوق، وتحتها الكتب ٢٠ ٢٠، والباقي بيتحمّل لما توصل لآخر القائمة.
class BookCategoryScreen extends StatefulWidget {
  const BookCategoryScreen({super.key, required this.category, required this.onBack, required this.onOpenBook});
  final BookCategory category;
  final VoidCallback onBack;
  final ValueChanged<LibraryBook> onOpenBook;

  @override
  State<BookCategoryScreen> createState() => _BookCategoryScreenState();
}

class _BookCategoryScreenState extends State<BookCategoryScreen> {
  final repo = BooksRepository.instance;
  List<BookCategory> _subs = [];
  late int _selected = widget.category.id;
  final _books = <LibraryBook>[];
  int _page = 0, _total = 1;
  bool _loading = false, _failed = false;

  @override
  void initState() {
    super.initState();
    repo.categories().then((all) {
      if (mounted) setState(() => _subs = all.where((x) => x.parent == widget.category.id).toList());
    }).catchError((_) {});
    _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _total) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final cat = _selected;
    try {
      final p = await repo.books(category: cat, page: _page + 1);
      if (!mounted || cat != _selected) return;
      setState(() {
        _page++;
        _total = p.totalPages;
        // الكتاب ممكن يكون في أكتر من صفحة لو اتنشر كتاب جديد وإحنا بنقلّب
        final ids = _books.map((b) => b.id).toSet();
        _books.addAll(p.books.where((b) => ids.add(b.id)));
      });
    } catch (_) {
      if (mounted && cat == _selected) setState(() => _failed = true);
    } finally {
      if (mounted && cat == _selected) setState(() => _loading = false);
    }
  }

  void _select(int id) {
    if (id == _selected) return;
    setState(() {
      _selected = id;
      _books.clear();
      _page = 0;
      _total = 1;
      _loading = false;
    });
    _more();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final chips = [BookCategory(widget.category.id, 'الكل', 0, widget.category.count), ..._subs];
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, pad.top, 16, pad.bottom + 24),
        children: [
          ScreenHeader(widget.category.name, subtitle: '${_count(widget.category.count)} كتاب', onBack: widget.onBack),
          if (_subs.isNotEmpty) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final on = chips[i].id == _selected;
                  return ChoiceChip(
                    label: Text(chips[i].name),
                    selected: on,
                    showCheckmark: false,
                    labelStyle: TextStyle(fontSize: 13, color: on ? c.onLive : c.textSoft),
                    selectedColor: c.live,
                    backgroundColor: c.chip,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    onSelected: (_) => _select(chips[i].id),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final b in _books) BookRow(book: b, onTap: () => widget.onOpenBook(b)),
          if (_failed)
            _Retry(onRetry: _more)
          else if (_loading)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (_books.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text('مافيش كتب هنا', style: TextStyle(color: c.textSoft))),
        ],
      ),
    );
  }
}

/// صفحة الكتاب: الغلاف والتعريف، و«اقرأ» و«تنزيل PDF».
class BookScreen extends StatelessWidget {
  const BookScreen({super.key, required this.book, required this.onBack, required this.onRead});
  final LibraryBook book;
  final VoidCallback onBack;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final repo = BooksRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final saved = repo.isSaved(book);
        final dl = repo.downloads[book.id];
        final busy = dl != null && !dl.done && dl.error == null;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top, 16, pad.bottom + 24),
          children: [
            ScreenHeader('الكتاب', onBack: onBack),
            Center(child: BookCover(book: book, width: 150, height: 206)),
            const SizedBox(height: 20),
            Text(book.title, textAlign: TextAlign.center, style: context.heading(size: 22)),
            if (book.author != null) ...[
              const SizedBox(height: 4),
              Text(book.author!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textSoft)),
            ],
            const SizedBox(height: 24),
            if (book.pdf == null)
              Text('الكتاب ده مالوش ملف تحميل في المكتبة', textAlign: TextAlign.center, style: TextStyle(color: c.textSoft))
            else ...[
              FilledButton.icon(
                onPressed: onRead,
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                label: Text(saved ? 'اقرأ' : 'اقرأ أونلاين'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.live,
                  foregroundColor: c.onLive,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              if (busy)
                Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: dl.progress, minHeight: 6, color: c.navGlow, backgroundColor: c.chip),
                  ),
                  const SizedBox(height: 6),
                  Text(dl.progress == null ? 'بيتنزّل…' : 'بيتنزّل ${_count((dl.progress! * 100).round())}٪',
                      style: TextStyle(fontSize: 12, color: c.textSoft)),
                ])
              else if (saved)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final f = await repo.fileOf(book);
                        await SharePlus.instance.share(ShareParams(
                          files: [XFile(f.path, mimeType: 'application/pdf', name: '${book.title}.pdf')],
                          subject: book.title,
                        ));
                      },
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('مشاركة الملف'),
                      style: _outlined(c),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => repo.remove(book),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('امسح من الموبايل'),
                      style: _outlined(c),
                    ),
                  ),
                ])
              else
                OutlinedButton.icon(
                  onPressed: () => repo.download(book),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('تنزيل PDF'),
                  style: _outlined(c).copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48))),
                ),
              if (dl?.error != null) ...[
                const SizedBox(height: 8),
                Text(dl!.error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.accent)),
              ],
            ],
            if (book.about.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('محتويات الكتاب', style: context.heading(size: 17)),
              const SizedBox(height: 8),
              for (final line in book.about.split('\n'))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
                  child: Text(line, style: TextStyle(fontSize: 14, height: 1.6, color: c.textSoft)),
                ),
            ],
            const SizedBox(height: 20),
            Text('المصدر: مكتبة الكتب المسيحية christianlib.com', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textFaint)),
          ],
        );
      },
    );
  }

  ButtonStyle _outlined(AppColors c) => OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.hairline),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

/// قارئ الـ PDF: من الموبايل لو متنزّل، أو من النت على طول.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({super.key, required this.book, required this.onBack});
  final LibraryBook book;
  final VoidCallback onBack;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final repo = BooksRepository.instance;
  late Future<Widget> _viewer = _open();
  final _controller = PdfViewerController();
  int _pages = 0, _pageNo = 1;

  Future<Widget> _open() async {
    final params = PdfViewerParams(
      backgroundColor: Colors.transparent,
      margin: 8,
      pageDropShadow: BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 6, offset: const Offset(0, 2)),
      onViewerReady: (doc, controller) {
        if (mounted) setState(() => _pages = doc.pages.length);
      },
      onPageChanged: (n) {
        if (n != null && mounted) setState(() => _pageNo = n);
      },
      loadingBannerBuilder: (context, got, total) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(value: total == null || total == 0 ? null : got / total),
          const SizedBox(height: 10),
          Text('بيفتح الكتاب…', style: TextStyle(color: context.colors.textSoft)),
        ]),
      ),
      errorBannerBuilder: (context, error, stack, ref) =>
          Center(child: Text('تعذّر فتح الكتاب', style: TextStyle(color: context.colors.textSoft))),
    );
    if (repo.isSaved(widget.book)) {
      final f = await repo.fileOf(widget.book);
      return PdfViewer.file(f.path, controller: _controller, params: params);
    }
    final url = await repo.directPdf(widget.book);
    return PdfViewer.uri(url, controller: _controller, params: params);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ScreenHeader(
            widget.book.title,
            subtitle: _pages == 0 ? widget.book.author : 'صفحة ${_count(_pageNo)} من ${_count(_pages)}',
            onBack: widget.onBack,
          ),
        ),
        Expanded(
          child: FutureBuilder<Widget>(
            future: _viewer,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('تعذّر فتح الكتاب، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
                    TextButton(
                      onPressed: () => setState(() => _viewer = _open()),
                      child: Text('حاول تاني', style: TextStyle(color: c.live)),
                    ),
                  ]),
                );
              }
              return snap.data ?? const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ]),
    );
  }
}

