import 'dart:core';

class KakaoBookModel {
  final List<KakaoDocumentItem> documents;

  const KakaoBookModel({required this.documents});

  factory KakaoBookModel.fromJson({required Map<String, dynamic> jsonData}){
    var list = jsonData["documents"] as List;
    List<KakaoDocumentItem> documents = list.map((item) => KakaoDocumentItem.fromJson(jsonData: item)).toList();

    return KakaoBookModel(
      documents: documents,
    );
  }
}

class KakaoDocumentItem {
  final String authors;
  final String contents;
  final String datetime;
  final String isbn;
  final int price;
  final String publisher;
  final int sale_price;
  final String thumbnail;
  final String title;
  final String translators;
  final String url;

  const KakaoDocumentItem({
    required this.authors,
    required this.contents,
    required this.datetime,
    required this.isbn,
    required this.price,
    required this.publisher,
    required this.sale_price,
    required this.thumbnail,
    required this.title,
    required this.translators,
    required this.url
  });

  factory KakaoDocumentItem.fromJson({required Map<String, dynamic> jsonData}){
    return KakaoDocumentItem(
      authors: jsonData["authors"].toString().replaceAll("[", "").replaceAll("]", ""),
      contents: jsonData["contents"],
      datetime: jsonData["datetime"],
      isbn: jsonData["isbn"],
      price: jsonData["price"],
      publisher: jsonData["publisher"],
      sale_price: jsonData["sale_price"],
      thumbnail: jsonData["thumbnail"],
      title: jsonData["title"],
      translators: jsonData["translators"].toString().replaceAll("[", "").replaceAll("]", ""),
      url: jsonData["url"]
    );
  }

  Map<String, dynamic> objToMap() {
    return {
      'authors': authors,
      'contents': contents,
      'datetime': datetime,
      'isbn': isbn,
      'price': price,
      'publisher': publisher,
      'sale_price': sale_price,
      'thumbnail': thumbnail,
      'title': title,
      'translators': translators,
      'url': url,
    };
  }
}