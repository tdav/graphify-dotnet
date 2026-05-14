using MiniLibrary.Infrastructure;
using MiniLibrary.Models;
using MiniLibrary.Services;

var seed = new[]
{
    new Book("b1", "The Pragmatic Programmer", "Hunt & Thomas"),
    new Book("b2", "Code Complete", "McConnell"),
    new Book("b3", "Refactoring", "Fowler"),
};

IInventory inventory = new InMemoryInventory(seed);
ILibraryService library = new LibraryService(inventory);

var alice = new Reader("r1", "Alice");
var bob = new Reader("r2", "Bob");

Console.WriteLine($"Alice borrows b1: {library.BorrowBook("b1", alice)}");
Console.WriteLine($"Bob borrows b1: {library.BorrowBook("b1", bob)}");
Console.WriteLine($"Bob borrows b2: {library.BorrowBook("b2", bob)}");
library.ReturnBook("b1");
Console.WriteLine($"Bob borrows b1 after Alice returned: {library.BorrowBook("b1", bob)}");
