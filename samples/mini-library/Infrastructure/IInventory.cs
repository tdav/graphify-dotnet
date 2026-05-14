using MiniLibrary.Models;

namespace MiniLibrary.Infrastructure;

public interface IInventory
{
    bool Reserve(Book book, Reader reader);
    void Release(Book book);
    IReadOnlyCollection<Book> AvailableBooks();
}
