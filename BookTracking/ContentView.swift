// MARK: - Book Detail View

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = true
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // Güncelleme gerekmiyor
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

import SwiftUI

// MARK: - Models
struct Book: Identifiable, Codable {
    let id = UUID()
    var title: String
    var author: String
    var totalPages: Int
    var isCompleted: Bool = false
    var readingRecords: [ReadingRecord] = []
    var coverImageData: Data? = nil // Kapak resmi verisi
    var dateAdded: Date = Date() // Eklenme tarihi
    
    var totalPagesRead: Int {
        readingRecords.reduce(0) { $0 + $1.pagesRead }
    }
    
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        if isCompleted { return 100 }
        return Double(totalPagesRead) / Double(totalPages) * 100
    }
    
    var remainingPages: Int {
        if isCompleted { return 0 }
        return max(0, totalPages - totalPagesRead)
    }
    
    // Kapak resmini UIImage olarak döndür
    var coverImage: UIImage? {
        guard let imageData = coverImageData else { return nil }
        return UIImage(data: imageData)
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
                    Image(systemName: "book.pages")
                    Text("Okunanlar")
                }
                .tag(0)
            
            UnreadBooksView(books: $books)
                .tabItem {
                    Image(systemName: "book.closed")
                    Text("Bekleyen")
                }
                .tag(1)
            
            CompletedBooksView(books: $books)
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("Tamamlanan")
                }
                .tag(2)
            
            AddBookView(books: $books, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Kitap Ekle")
                }
                .tag(3)
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
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            Form {
                // Kapak Resmi Bölümü
                Section(header: Text("Kapak Resmi")) {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 160)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 160)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "book.closed")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("Kapak Resmi")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            Button(selectedImage == nil ? "Resim Seç" : "Resmi Değiştir") {
                                showingActionSheet = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            
                            if selectedImage != nil {
                                Button("Resmi Kaldır") {
                                    selectedImage = nil
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
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
                    selectedTab = 1
                }
            }
        } message: {
            Text(alertMessage)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Kapak Resmi Seç"),
                buttons: [
                    .default(Text("Kameradan Çek")) {
                        imageSourceType = .camera
                        showingImagePicker = true
                    },
                    .default(Text("Galeriden Seç")) {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
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
        
        var newBook = Book(title: title, author: author, totalPages: pages)
        
        // Resmi Data formatında kaydet
        if let selectedImage = selectedImage {
            newBook.coverImageData = selectedImage.jpegData(compressionQuality: 0.7)
        }
        
        books.append(newBook)
        saveBooks()
        
        // Formu temizle
        title = ""
        author = ""
        totalPages = ""
        selectedImage = nil
        
        alertMessage = "Kitap başarıyla eklendi!"
        showingAlert = true
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Book List View (Okuması Devam Edenler)
struct BookListView: View {
    @Binding var books: [Book]
    @State private var showingEditBook = false
    @State private var editingBookIndex: Int?
    
    // Sadece okumaya başlanmış ama tamamlanmamış kitaplar
    var readingBooks: [Book] {
        books.filter { !$0.isCompleted && $0.totalPagesRead > 0 }
            .sorted { $0.progressPercentage > $1.progressPercentage }
    }
    
    var body: some View {
        NavigationView {
            List {
                if readingBooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Henüz okumakta olduğunuz kitap yok")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Bekleyen kitaplarınızdan birini seçin ve okumaya başlayın!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    // Sıralama bilgisi
                    Section {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.blue)
                            Text("İlerlemeye göre sıralandı")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(readingBooks.count) okunmakta")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ForEach(readingBooks, id: \.id) { book in
                        if let bookIndex = books.firstIndex(where: { $0.id == book.id }) {
                            NavigationLink(destination: BookDetailView(book: $books[bookIndex], saveAction: saveBooks)) {
                                ReadingBookRowView(
                                    book: book,
                                    onEdit: {
                                        editingBookIndex = bookIndex
                                        showingEditBook = true
                                    },
                                    onToggleComplete: {
                                        books[bookIndex].isCompleted.toggle()
                                        saveBooks()
                                    }
                                )
                            }
                        }
                    }
                    .onDelete(perform: deleteBooks)
                }
            }
            .navigationTitle("Okunan Kitaplar")
            .toolbar {
                if !readingBooks.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingEditBook) {
            if let index = editingBookIndex {
                EditBookView(
                    book: $books[index],
                    saveAction: saveBooks
                )
            }
        }
    }
    
    func deleteBooks(offsets: IndexSet) {
        let booksToDelete = offsets.map { readingBooks[$0] }
        
        for bookToDelete in booksToDelete {
            if let index = books.firstIndex(where: { $0.id == bookToDelete.id }) {
                books.remove(at: index)
            }
        }
        
        saveBooks()
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Unread Books View (Bekleyen Kitaplar)
struct UnreadBooksView: View {
    @Binding var books: [Book]
    @State private var showingEditBook = false
    @State private var editingBookIndex: Int?
    
    // Hiç okunmaya başlanmamış kitaplar
    var unreadBooks: [Book] {
        books.filter { !$0.isCompleted && $0.totalPagesRead == 0 }
            .sorted { $0.dateAdded < $1.dateAdded } // Eskiden yeniye (yeni eklenenler altta)
    }
    
    var body: some View {
        NavigationView {
            List {
                if unreadBooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Bekleyen kitabınız yok")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Yeni kitap ekleyin ve okuma listenizi oluşturun!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    // Bilgi bölümü
                    Section {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.orange)
                            Text("Okuma listeniz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(unreadBooks.count) bekleyen kitap")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ForEach(unreadBooks, id: \.id) { book in
                        if let bookIndex = books.firstIndex(where: { $0.id == book.id }) {
                            NavigationLink(destination: BookDetailView(book: $books[bookIndex], saveAction: saveBooks)) {
                                UnreadBookRowView(
                                    book: book,
                                    onEdit: {
                                        editingBookIndex = bookIndex
                                        showingEditBook = true
                                    }
                                )
                            }
                        }
                    }
                    .onDelete(perform: deleteBooks)
                }
            }
            .navigationTitle("Bekleyen Kitaplar")
            .toolbar {
                if !unreadBooks.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingEditBook) {
            if let index = editingBookIndex {
                EditBookView(
                    book: $books[index],
                    saveAction: saveBooks
                )
            }
        }
    }
    
    func deleteBooks(offsets: IndexSet) {
        let booksToDelete = offsets.map { unreadBooks[$0] }
        
        for bookToDelete in booksToDelete {
            if let index = books.firstIndex(where: { $0.id == bookToDelete.id }) {
                books.remove(at: index)
            }
        }
        
        saveBooks()
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Completed Books View
struct CompletedBooksView: View {
    @Binding var books: [Book]
    @State private var showingEditBook = false
    @State private var editingBookIndex: Int?
    
    var completedBooks: [Book] {
        books.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            List {
                if completedBooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Henüz tamamlanan kitabınız yok")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Bir kitabı bitirdiğinizde burada görünecek!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    // İstatistikler Bölümü
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundColor(.green)
                                Text("Toplam \(completedBooks.count) kitap tamamladınız!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            let totalPages = completedBooks.reduce(0) { $0 + $1.totalPages }
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Toplam \(totalPages) sayfa okudunuz")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    
                    // Tamamlanan Kitaplar
                    Section("Tamamlanan Kitaplar") {
                        ForEach(books.indices, id: \.self) { index in
                            if books[index].isCompleted {
                                NavigationLink(destination: BookDetailView(book: $books[index], saveAction: saveBooks)) {
                                    CompletedBookRowView(
                                        book: books[index],
                                        onEdit: {
                                            editingBookIndex = index
                                            showingEditBook = true
                                        },
                                        onToggleComplete: {
                                            books[index].isCompleted.toggle()
                                            saveBooks()
                                        }
                                    )
                                }
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("Tamamlanan Kitaplar")
            .toolbar {
                if !completedBooks.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingEditBook) {
            if let index = editingBookIndex {
                EditBookView(
                    book: $books[index],
                    saveAction: saveBooks
                )
            }
        }
    }
    
    func deleteBooks(offsets: IndexSet) {
        let completedBookIndices = books.enumerated().compactMap { index, book in
            book.isCompleted ? index : nil
        }
        
        let indicesToDelete = offsets.map { completedBookIndices[$0] }
        
        for index in indicesToDelete.sorted(by: >) {
            books.remove(at: index)
        }
        
        saveBooks()
    }
    
    func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "books")
        }
    }
}

// MARK: - Reading Book Row View (Okuması Devam Edenler)
struct ReadingBookRowView: View {
    let book: Book
    let onEdit: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Kapak resmi
            if let coverImage = book.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .cornerRadius(6)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 65)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Image(systemName: "book.pages")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                
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
            
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Button(action: onToggleComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Unread Book Row View (Bekleyenler)
struct UnreadBookRowView: View {
    let book: Book
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Kapak resmi
            if let coverImage = book.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .cornerRadius(6)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 65)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Image(systemName: "book.closed")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(book.totalPages) sayfa")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Henüz başlanmadı")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // İlerleme çubuğu (boş)
                ProgressView(value: 0, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .gray.opacity(0.3)))
            }
            
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Placeholder for future "start reading" feature
                Button(action: {}) {
                    Image(systemName: "play.circle")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .disabled(true)
                .opacity(0.5)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Completed Book Row View
struct CompletedBookRowView: View {
    let book: Book
    let onEdit: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Kapak resmi
            if let coverImage = book.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .cornerRadius(6)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .background(Color.white.clipShape(Circle()))
                                    .font(.system(size: 16))
                            }
                            Spacer()
                        }
                        .padding(4)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 65)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .background(Color.white.clipShape(Circle()))
                                    .font(.system(size: 16))
                            }
                            Spacer()
                        }
                        .padding(4)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(book.totalPages) sayfa")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Tamamlandı ✅")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                // Son okuma tarihi
                if let lastRecord = book.readingRecords.max(by: { $0.date < $1.date }) {
                    Text("Son okuma: \(DateFormatter.shortDate.string(from: lastRecord.date))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Button(action: onToggleComplete) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Book Detail View
struct BookDetailView: View {
    @Binding var book: Book
    let saveAction: () -> Void
    @State private var showingAddRecord = false
    @State private var showingEditRecord = false
    @State private var showingEditBook = false
    @State private var editingRecordIndex: Int?
    
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
                    HStack {
                        Text("Okuma İlerlemesi")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(book.isCompleted ? "Devam Et" : "Tamamlandı") {
                            book.isCompleted.toggle()
                            saveAction()
                        }
                        .font(.subheadline)
                        .foregroundColor(book.isCompleted ? .orange : .green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(book.isCompleted ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if book.isCompleted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Kitap tamamlandı!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                    }
                    
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
                                .foregroundColor(book.isCompleted ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Tamamlanma Yüzdesi:")
                            Spacer()
                            Text(book.isCompleted ? "Tamamlandı" : "%\(String(format: "%.1f", book.progressPercentage))")
                                .fontWeight(.semibold)
                                .foregroundColor(book.isCompleted ? .green : .blue)
                        }
                        
                        ProgressView(value: book.progressPercentage, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: book.isCompleted ? .green : .blue))
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
                            if let index = book.readingRecords.firstIndex(where: { $0.id == record.id }) {
                                ReadingRecordRow(
                                    record: record,
                                    onEdit: {
                                        editingRecordIndex = index
                                        showingEditRecord = true
                                    },
                                    onDelete: {
                                        book.readingRecords.remove(at: index)
                                        saveAction()
                                    }
                                )
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Düzenle") {
                    showingEditBook = true
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddReadingRecordView(book: $book, saveAction: saveAction)
        }
        .sheet(isPresented: $showingEditRecord) {
            if let index = editingRecordIndex {
                EditReadingRecordView(
                    book: $book,
                    recordIndex: index,
                    saveAction: saveAction
                )
            }
        }
        .sheet(isPresented: $showingEditBook) {
            EditBookView(book: $book, saveAction: saveAction)
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
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateFormatter.shortDate.string(from: record.date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Sayfa \(record.startPage) - \(record.endPage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(record.pagesRead) sayfa")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showingDeleteAlert = true }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .alert("Kayıt Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Bu okuma kaydını silmek istediğinize emin misiniz?")
        }
    }
}

// MARK: - Edit Book View
struct EditBookView: View {
    @Binding var book: Book
    let saveAction: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title: String
    @State private var author: String
    @State private var totalPages: String
    @State private var isCompleted: Bool
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    init(book: Binding<Book>, saveAction: @escaping () -> Void) {
        self._book = book
        self.saveAction = saveAction
        
        let bookValue = book.wrappedValue
        self._title = State(initialValue: bookValue.title)
        self._author = State(initialValue: bookValue.author)
        self._totalPages = State(initialValue: String(bookValue.totalPages))
        self._isCompleted = State(initialValue: bookValue.isCompleted)
        self._selectedImage = State(initialValue: bookValue.coverImage)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Kapak Resmi Bölümü
                Section(header: Text("Kapak Resmi")) {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 160)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 160)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "book.closed")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("Kapak Resmi")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            Button(selectedImage == nil ? "Resim Seç" : "Resmi Değiştir") {
                                showingActionSheet = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            
                            if selectedImage != nil {
                                Button("Resmi Kaldır") {
                                    selectedImage = nil
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Kitap Bilgileri")) {
                    TextField("Kitap Adı", text: $title)
                    TextField("Yazar", text: $author)
                    TextField("Toplam Sayfa Sayısı", text: $totalPages)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Durum")) {
                    Toggle("Kitap Tamamlandı", isOn: $isCompleted)
                }
                
                Section {
                    Button(action: updateBook) {
                        HStack {
                            Spacer()
                            Text("Güncelle")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Kitabı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("İptal") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Güncelle") {
                    updateBook()
                }
            )
        }
        .alert("Uyarı", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Kapak Resmi Seç"),
                buttons: [
                    .default(Text("Kameradan Çek")) {
                        imageSourceType = .camera
                        showingImagePicker = true
                    },
                    .default(Text("Galeriden Seç")) {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
        }
    }
    
    func updateBook() {
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
        
        book.title = title
        book.author = author
        book.totalPages = pages
        book.isCompleted = isCompleted
        
        // Resmi güncelle
        if let selectedImage = selectedImage {
            book.coverImageData = selectedImage.jpegData(compressionQuality: 0.7)
        } else {
            book.coverImageData = nil
        }
        
        saveAction()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Edit Reading Record View
struct EditReadingRecordView: View {
    @Binding var book: Book
    let recordIndex: Int
    let saveAction: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var date: Date
    @State private var startPage: String
    @State private var endPage: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(book: Binding<Book>, recordIndex: Int, saveAction: @escaping () -> Void) {
        self._book = book
        self.recordIndex = recordIndex
        self.saveAction = saveAction
        
        let record = book.wrappedValue.readingRecords[recordIndex]
        self._date = State(initialValue: record.date)
        self._startPage = State(initialValue: String(record.startPage))
        self._endPage = State(initialValue: String(record.endPage))
    }
    
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
                    Button(action: updateRecord) {
                        HStack {
                            Spacer()
                            Text("Güncelle")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Kaydı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("İptal") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Güncelle") {
                    updateRecord()
                }
            )
        }
        .alert("Uyarı", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func updateRecord() {
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
        
        book.readingRecords[recordIndex].date = date
        book.readingRecords[recordIndex].startPage = start
        book.readingRecords[recordIndex].endPage = end
        
        saveAction()
        presentationMode.wrappedValue.dismiss()
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
    
