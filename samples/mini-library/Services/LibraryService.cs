using MiniLibrary.Infrastructure;
using MiniLibrary.Models;

namespace MiniLibrary.Services;

public sealed class LibraryService : ILibraryService
{
    private readonly IInventory inventory;

    public LibraryService(IInventory inventory)
    {
        this.inventory = inventory;
    }

    public bool BorrowBook(string bookId, Reader reader)
    {
        var book = this.inventory.AvailableBooks().FirstOrDefault(b => b.Id == bookId);
        if (book is null)
        {
            return false;
        }

        return this.inventory.Reserve(book, reader);
    }

    public void ReturnBook(string bookId)
    {
        var book = new Book(bookId, Title: string.Empty, Author: string.Empty);
        this.inventory.Release(book);
    }
}
