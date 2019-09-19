
extern crate tantivy;
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::tokenizer::Tokenizer;
use tantivy::tokenizer::{LowerCaser, NgramTokenizer};
use tantivy::{Index, IndexWriter};
// use serde::{Serialize, Deserialize};

pub struct CitiesSearcher {
    schema: Schema,
    index: Index,
    index_writer: IndexWriter,
}

// #[derive(Serialize, Deserialize)]
// pub struct City {
//     id: String,
//     name: String,
//     insee: String,
// }

impl Default for CitiesSearcher {
    fn default() -> CitiesSearcher {
        let mut schema_builder = Schema::builder();
        let ngrams_indexing = TextFieldIndexing::default()
            .set_tokenizer("ngram3")
            .set_index_option(IndexRecordOption::WithFreqsAndPositions);

        let int_options = IntOptions::default()
            .set_stored();
        let _id = schema_builder.add_u64_field("id", int_options);

        let name_options = TextOptions::default()
            .set_indexing_options(ngrams_indexing.clone());
        let _name = schema_builder.add_text_field("name", name_options);

        let insee_options = TextOptions::default()
            .set_indexing_options(ngrams_indexing);
        let _insee = schema_builder.add_text_field("insee", insee_options);

        let schema = schema_builder.build();

        let index = Index::create_in_ram(schema.clone());
        index.tokenizers().register(
            "ngram3",
            NgramTokenizer::new(1, 100, true).filter(LowerCaser),
        );
        let index_writer = index.writer(500_000_000).unwrap();

        CitiesSearcher {
            schema,
            index,
            index_writer,
        }
    }
}

impl CitiesSearcher {

    pub fn add_cities(&mut self, docs: Vec<(u64, String, String)>) -> tantivy::Result<()> {
        println!("adding entries {}", docs.len());

        let schema_id = self.schema.get_field("id").unwrap();
        let schema_name = self.schema.get_field("name").unwrap();
        let schema_insee = self.schema.get_field("insee").unwrap();

        for d in docs {
            self.index_writer.add_document(doc!(
                schema_id => d.0,
                schema_name => d.1,
                schema_insee => d.2,
            ));
        }

        self.index_writer.commit()?;

        println!("adding done");
        Ok(())
    }

    pub fn search(&self, query: String) -> tantivy::Result<Vec<Document>> {
        let searcher = self.index.reader()?.searcher();

        let query_parser = QueryParser::for_index(
            &self.index,
            vec![
                self.schema.get_field("name").unwrap(),
                self.schema.get_field("insee").unwrap(),
            ],
        );

        let query = query_parser.parse_query(&query)?;
        let top_docs = searcher.search(&*query, &TopDocs::with_limit(10))?;

        let docs = top_docs
            .iter()
            .map(|(_score, doc_address)| searcher.doc(*doc_address).unwrap())
            .collect();

        Ok(docs)
    }
}
