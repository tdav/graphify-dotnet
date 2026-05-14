using MiniLibrary.Models;

namespace MiniLibrary.Infrastructure;

public sealed class InMemoryInventory : IInventory
{
    private readonly Dictionary<string, Book> books = new();
    private readonly Dictionary<string, Reader> reservations = new();

    public InMemoryInventory(IEnumerable<Book> seed)
    {
        foreach (var book in seed)
        {
            this.books[book.Id] = book;
        }
    }

    public bool Reserve(Book book, Reader reader)
    {
        if (!this.books.ContainsKey(book.Id) || this.reservations.ContainsKey(book.Id))
        {
            return false;
        }

        this.reservations[book.Id] = reader;
        return true;
    }

    public void Release(Book book)
    {
        this.reservations.Remove(book.Id);
    }

    public IReadOnlyCollection<Book> AvailableBooks()
    {
        return this.books.Values
            .Where(b => !this.reservations.ContainsKey(b.Id))
            .ToList();
    }
}
