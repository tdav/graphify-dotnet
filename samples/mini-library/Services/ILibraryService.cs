using MiniLibrary.Models;

namespace MiniLibrary.Services;

public interface ILibraryService
{
    bool BorrowBook(string bookId, Reader reader);
    void ReturnBook(string bookId);
}
