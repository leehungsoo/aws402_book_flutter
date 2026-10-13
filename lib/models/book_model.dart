import 'dart:convert';

class BookModel {
  final BookResult bookResult;

  const BookModel({required this.bookResult});
}

class BookResult {
  final BookHeader header;
  final BookBody body;

  const BookResult({required this.header, required this.body});

  factory BookResult.fromJson({required Map<String, dynamic> jsonData}){
    return BookResult(
      header: jsonData["header"],
      body: jsonData["body"]
    );
  }
}

class BookHeader {
  final String resultCode;
  final String resultMsg;

  const BookHeader({required this.resultCode, required this.resultMsg});

  factory BookHeader.fromJson({required Map<String, dynamic> jsonData}){
    return BookHeader(
      resultCode: jsonData["resultCode"],
      resultMsg: jsonData["resultMsg"]
    );
  }
}

class BookBody {
  final int totalCount;
  final int pageNo;
  final int numOfRows;
  final List<BookItem> bookItems;

  const BookBody({required this.totalCount, required this.pageNo, required this.numOfRows, required this.bookItems});

  factory BookBody.fromJson({required Map<String, dynamic> jsonData}){
    var list = jsonData["items"] as List;
    List<BookItem> bookItems = list.map((item) => BookItem.fromJson(jsonData: item)).toList();
    return BookBody(
      totalCount: jsonData["totalCount"],
      pageNo: jsonData["pageNo"],
      numOfRows: jsonData["numOfRows"],
      bookItems: bookItems
    );
  }
}

class BookItem {
  final String BIBLIO_ID;
  final String DCTERMS_title;
  final String RDFS_label;

  const BookItem({
    required this.BIBLIO_ID,
    required this.DCTERMS_title,
    required this.RDFS_label
  });

  factory BookItem.fromJson({required Map<String, dynamic> jsonData}){
    return BookItem(
      BIBLIO_ID: jsonData["BIBLIO_ID"],
      DCTERMS_title: jsonData["DCTERMS_title"],
      RDFS_label: jsonData["RDFS_label"]
    );
  }

}