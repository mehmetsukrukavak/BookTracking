import SwiftUI

// MARK: - Models
struct Book: Identifiable, Codable {
    let id = UUID()
    var title: String
    var author: String
    var totalPages: Int
    var readingRecords: [ReadingRecord] = []
    
    var totalPagesRead: Int {
        readingRecords.reduce(0) { $0 + $1.pagesRead }
    }
    
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(totalPagesRead) / Double(totalPages) * 100
    }
    
    var remainingPages: Int {
        max(0, totalPages - totalPagesRead)
    }
}

struct ReadingRecord: Identifiable, Codable {
    let id = UUID()
    var date: Date
    var startPage: Int
    var endPage: Int
    
    var pagesRead: Int {
        max(0, endPage - startPage + 1)
    }
}



// MARK: - Content View
struct ContentView: View {
    @State private var books: [Book] = []
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BookListView(books: $books)
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("Kitaplar")
                }
                .tag(0)
            
            AddBookView(books: $books, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Kitap Ekle")
                }
                .tag(1)
        }
        .onAppear {
            loadBooks()
        }
    }
    
    func loadBooks() {
        if let data = UserDefaults.standard.data(forKey: "books"),
           let decodedBooks = try? JSONDecoder().decode([Book].self, from: data) {
            books = decodedBooks
        }
    }
}

// MARK: - Add Book View
struct AddBookView: View {
    @Binding var books: [Book]
    @Binding var selectedTab: Int
    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Kitap Bilgileri")) {
                    TextField("Kitap Adı", text: $title)
                    TextField("Yazar", text: $author)
                    TextField("Toplam Sayfa Sayısı", text: $totalPages)
                        .keyboardType(.numberPad)
                }
                
                Button(action: addBook) {
                    HStack {
                        Spacer()
                        Text("Kitap Ekle")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .listRowBackground(Color.blue)
            }
            .navigationTitle("Yeni Kitap")
        }
        .alert("Bilgi", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) {
                if alertMessage == "Kitap başarıyla eklendi!" {
                    // Kitap başarıyla eklendiyse ana sekmeye dön
                    selectedTab = 0
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    func addBook() {
        guard !title.isEmpty, !author.isEmpty else {
            alertMessage = "Lütfen kitap adı ve yazar bilgilerini girin."
            showingAlert = true
            return
        }
        
        guard let pages = Int(totalPages), pages > 0 else {
            alertMessage = "Lütfen geçerli bir sayfa sayısı girin."
            showingAlert = true
            return
        }
        
        let newBook = Book(title: title, author: author, totalPages: pages)
        books.append(newBook)
        saveBooks()
        
        // Formu temizle
        title = ""
        author = ""
        totalPages = ""
        
        alertMessage = "Kitap başarıyla eklendi!"
        showingAlert = true
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Book List View
struct BookListView: View {
    @Binding var books: [Book]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(books.indices, id: \.self) { index in
                    NavigationLink(destination: BookDetailView(book: $books[index], saveAction: saveBooks)) {
                        BookRowView(book: books[index])
                    }
                }
                .onDelete(perform: deleteBooks)
            }
            .navigationTitle("Kitaplarım")
            .toolbar {
                EditButton()
            }
        }
    }
    
    func deleteBooks(offsets: IndexSet) {
        books.remove(atOffsets: offsets)
        saveBooks()
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Book Row View
struct BookRowView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(book.author)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(book.totalPagesRead)/\(book.totalPages) sayfa")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("%\(String(format: "%.1f", book.progressPercentage))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: book.progressPercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Book Detail View
struct BookDetailView: View {
    @Binding var book: Book
    let saveAction: () -> Void
    @State private var showingAddRecord = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kitap Bilgileri
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kitap Bilgileri")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    InfoRow(title: "Başlık", value: book.title)
                    InfoRow(title: "Yazar", value: book.author)
                    InfoRow(title: "Toplam Sayfa", value: "\(book.totalPages)")
                }
                
                Divider()
                
                // İlerleme Bilgileri
                VStack(alignment: .leading, spacing: 12) {
                    Text("Okuma İlerlemesi")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Okunan Sayfa:")
                            Spacer()
                            Text("\(book.totalPagesRead)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Kalan Sayfa:")
                            Spacer()
                            Text("\(book.remainingPages)")
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("Tamamlanma Yüzdesi:")
                            Spacer()
                            Text("%\(String(format: "%.1f", book.progressPercentage))")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: book.progressPercentage, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                }
                
                Divider()
                
                // Okuma Kayıtları
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Okuma Kayıtları")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button("Yeni Kayıt") {
                            showingAddRecord = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if book.readingRecords.isEmpty {
                        Text("Henüz okuma kaydı bulunmuyor.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(book.readingRecords.sorted(by: { $0.date > $1.date })) { record in
                            ReadingRecordRow(record: record)
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddRecord) {
            AddReadingRecordView(book: $book, saveAction: saveAction)
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Reading Record Row
struct ReadingRecordRow: View {
    let record: ReadingRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatter.shortDate.string(from: record.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(record.pagesRead) sayfa")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            
            Text("Sayfa \(record.startPage) - \(record.endPage)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Add Reading Record View
struct AddReadingRecordView: View {
    @Binding var book: Book
    let saveAction: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var date = Date()
    @State private var startPage = ""
    @State private var endPage = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Okuma Bilgileri")) {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    
                    TextField("Başlangıç Sayfası", text: $startPage)
                        .keyboardType(.numberPad)
                    
                    TextField("Bitiş Sayfası", text: $endPage)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: addRecord) {
                        HStack {
                            Spacer()
                            Text("Kaydet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Okuma Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("İptal") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Kaydet") {
                    addRecord()
                }
            )
        }
        .alert("Uyarı", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func addRecord() {
        guard let start = Int(startPage), let end = Int(endPage) else {
            alertMessage = "Lütfen geçerli sayfa numaraları girin."
            showingAlert = true
            return
        }
        
        guard start > 0, end > 0, start <= end else {
            alertMessage = "Başlangıç sayfası bitiş sayfasından küçük veya eşit olmalıdır."
            showingAlert = true
            return
        }
        
        guard end <= book.totalPages else {
            alertMessage = "Bitiş sayfası kitabın toplam sayfa sayısını geçemez."
            showingAlert = true
            return
        }
        
        let newRecord = ReadingRecord(date: date, startPage: start, endPage: end)
        book.readingRecords.append(newRecord)
        saveAction()
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()
}
