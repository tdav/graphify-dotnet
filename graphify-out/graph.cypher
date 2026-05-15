// Knowledge Graph Export to Neo4j
// Generated: 2026-05-14 18:53:59
// Nodes: 40, Edges: 59

// Clear existing data (optional - uncomment if needed)
// MATCH (n) DETACH DELETE n;

// Create nodes

CREATE (ninmemoryinventory_minilibrary_infrastructure:Entity {id: "inmemoryinventory_minilibrary_infrastructure", label: "MiniLibrary.Infrastructure", community: 3, source_location: "L2"});
CREATE (ninmemoryinventory_availablebooks:Entity {id: "inmemoryinventory_availablebooks", label: "AvailableBooks()", community: 3, source_location: "L33"});
CREATE (ninmemoryinventory_foreach:Entity {id: "inmemoryinventory_foreach", label: "foreach()", community: 3, source_location: "L12"});
CREATE (ninmemoryinventory_if:Entity {id: "inmemoryinventory_if", label: "if()", community: 3, source_location: "L20"});
CREATE (ninmemoryinventory:Entity {id: "inmemoryinventory", label: "InMemoryInventory.cs", community: 3, source_location: "L1"});
CREATE (nprogram:Entity {id: "program", label: "Program.cs", community: 7, source_location: "L1"});
CREATE (nbook_book:Entity {id: "book_book", label: "Book()", community: 6, source_location: "L2"});
CREATE (nbook_minilibrary_models:Entity {id: "book_minilibrary_models", label: "MiniLibrary.Models", community: 6, source_location: "L1"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_465:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Program.cs", label: "Program.cs", community: 7, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Program.cs"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_139:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Models\\Book.cs", label: "Book.cs", community: 6, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Models\\Book.cs"});
CREATE (nbook:Entity {id: "book", label: "Book.cs", community: 6, source_location: "L1"});
CREATE (nilibraryservice_returnbook:Entity {id: "ilibraryservice_returnbook", label: "ReturnBook()", community: 2, source_location: "L8"});
CREATE (nilibraryservice:Entity {id: "ilibraryservice", label: "ILibraryService.cs", community: 2, source_location: "L1"});
CREATE (niinventory_reserve:Entity {id: "iinventory_reserve", label: "Reserve()", community: 1, source_location: "L7"});
CREATE (nilibraryservice_ilibraryservice:Entity {id: "ilibraryservice_ilibraryservice", label: "ILibraryService", community: 2, source_location: "L4"});
CREATE (niinventory_minilibrary_infrastructure:Entity {id: "iinventory_minilibrary_infrastructure", label: "MiniLibrary.Infrastructure", community: 1, source_location: "L2"});
CREATE (nilibraryservice_borrowbook:Entity {id: "ilibraryservice_borrowbook", label: "BorrowBook()", community: 2, source_location: "L7"});
CREATE (niinventory_release:Entity {id: "iinventory_release", label: "Release()", community: 1, source_location: "L8"});
CREATE (nilibraryservice_minilibrary_services:Entity {id: "ilibraryservice_minilibrary_services", label: "MiniLibrary.Services", community: 2, source_location: "L2"});
CREATE (niinventory_availablebooks:Entity {id: "iinventory_availablebooks", label: "AvailableBooks()", community: 1, source_location: "L9"});
CREATE (niinventory:Entity {id: "iinventory", label: "IInventory.cs", community: 1, source_location: "L1"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Infrastructure\\IInventory.cs", label: "IInventory.cs", community: 1, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Infrastructure\\IInventory.cs"});
CREATE (nlibraryservice:Entity {id: "libraryservice", label: "LibraryService.cs", community: 0, source_location: "L1"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Services\\LibraryService.cs", label: "LibraryService.cs", community: 0, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Services\\LibraryService.cs"});
CREATE (nlibraryservice_returnbook:Entity {id: "libraryservice_returnbook", label: "ReturnBook()", community: 0, source_location: "L25"});
CREATE (nlibraryservice_libraryservice:Entity {id: "libraryservice_libraryservice", label: "LibraryService()", community: 0, source_location: "L9"});
CREATE (nlibraryservice_minilibrary_services:Entity {id: "libraryservice_minilibrary_services", label: "MiniLibrary.Services", community: 0, source_location: "L3"});
CREATE (nreader_minilibrary_models:Entity {id: "reader_minilibrary_models", label: "MiniLibrary.Models", community: 5, source_location: "L1"});
CREATE (ninmemoryinventory_reserve:Entity {id: "inmemoryinventory_reserve", label: "Reserve()", community: 4, source_location: "L17"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_304:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Models\\Reader.cs", label: "Reader.cs", community: 5, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Models\\Reader.cs"});
CREATE (ninmemoryinventory_inmemoryinventory:Entity {id: "inmemoryinventory_inmemoryinventory", label: "InMemoryInventory()", community: 4, source_location: "L9"});
CREATE (ninmemoryinventory_release:Entity {id: "inmemoryinventory_release", label: "Release()", community: 4, source_location: "L28"});
CREATE (nreader:Entity {id: "reader", label: "Reader.cs", community: 5, source_location: "L1"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Infrastructure\\InMemoryInventory.cs", label: "InMemoryInventory.cs", community: 4, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Infrastructure\\InMemoryInventory.cs"});
CREATE (nprogram_book:Entity {id: "program_book", label: "Book()", community: 7, merge_count: "3", source_location: "L9"});
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886:File {id: "file:C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Services\\ILibraryService.cs", label: "ILibraryService.cs", community: 2, full_path: "C:\\Works_AI\\graphify-dotnet\\samples\\mini-library\\Services\\ILibraryService.cs"});
CREATE (niinventory_iinventory:Entity {id: "iinventory_iinventory", label: "IInventory", community: 1, source_location: "L4"});
CREATE (nlibraryservice_borrowbook:Entity {id: "libraryservice_borrowbook", label: "BorrowBook()", community: 0, source_location: "L14"});
CREATE (nlibraryservice_if:Entity {id: "libraryservice_if", label: "if()", community: 0, source_location: "L18"});
CREATE (nreader_reader:Entity {id: "reader_reader", label: "Reader()", community: 5, source_location: "L2"});

// Create relationships

CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_minilibrary_infrastructure);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_inmemoryinventory);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_foreach);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_reserve);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_if);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_release);
CREATE (ninmemoryinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_availablebooks);
CREATE (nprogram)-[:CONTAINS {weight: 3,00, confidence: "EXTRACTED"}]->(nprogram_book);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_465)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nprogram);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_465)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nprogram_book);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_139)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nbook);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_139)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nbook_book);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_139)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nbook_minilibrary_models);
CREATE (nbook)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nbook_minilibrary_models);
CREATE (nbook)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nbook_book);
CREATE (nilibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_minilibrary_services);
CREATE (nilibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_ilibraryservice);
CREATE (nilibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_borrowbook);
CREATE (nilibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_returnbook);
CREATE (niinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_minilibrary_infrastructure);
CREATE (niinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_iinventory);
CREATE (niinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_reserve);
CREATE (niinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_release);
CREATE (niinventory)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_availablebooks);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_minilibrary_infrastructure);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_iinventory);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_reserve);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_release);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_827)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(niinventory_availablebooks);
CREATE (nlibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_minilibrary_services);
CREATE (nlibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_libraryservice);
CREATE (nlibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_borrowbook);
CREATE (nlibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_if);
CREATE (nlibraryservice)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_returnbook);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_minilibrary_services);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_libraryservice);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_borrowbook);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_if);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_184)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nlibraryservice_returnbook);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_304)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nreader);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_304)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nreader_minilibrary_models);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_304)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nreader_reader);
CREATE (nreader)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nreader_minilibrary_models);
CREATE (nreader)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nreader_reader);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_availablebooks);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_foreach);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_if);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_minilibrary_infrastructure);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_inmemoryinventory);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_reserve);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_651)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(ninmemoryinventory_release);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_minilibrary_services);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_ilibraryservice);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_borrowbook);
CREATE (nfile_C__Works_AI_graphify_dotnet_samples_mini_886)-[:CONTAINS {weight: 1,00, confidence: "EXTRACTED"}]->(nilibraryservice_returnbook);

// Create indexes for better query performance

CREATE INDEX IF NOT EXISTS FOR (n:Entity) ON (n.id);
CREATE INDEX IF NOT EXISTS FOR (n:Entity) ON (n.label);
CREATE INDEX IF NOT EXISTS FOR (n:File) ON (n.id);
CREATE INDEX IF NOT EXISTS FOR (n:File) ON (n.label);

// Index for community-based queries
CREATE INDEX IF NOT EXISTS FOR (n:Entity) ON (n.community);
CREATE INDEX IF NOT EXISTS FOR (n:File) ON (n.community);

// Query examples:
// - Find all nodes: MATCH (n) RETURN n LIMIT 25;
// - Find nodes by type: MATCH (n:Class) RETURN n LIMIT 25;
// - Find nodes in a community: MATCH (n) WHERE n.community = 1 RETURN n;
// - Find highly connected nodes: MATCH (n) RETURN n, size((n)--()) as degree ORDER BY degree DESC LIMIT 10;
// - Find paths: MATCH p=shortestPath((a)-[*]-(b)) WHERE a.id='Node1' AND b.id='Node2' RETURN p;
