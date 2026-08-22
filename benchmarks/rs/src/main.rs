//! Reference benchmark: Gregor Purdy's Rust minbpe on the same workload.
//!
//! Mirrors benchmark.mojo and benchmark.py exactly -- same corpus, same 512
//! vocab, same warmup and round counts, same per-phase timing -- so
//! results_rust.json is directly comparable to the Mojo and Python results.
//!
//!     cargo run --release --manifest-path benchmarks/rs/Cargo.toml

use std::fs;
use std::time::{Duration, Instant};

use minbpe::{BasicTokenizer, RegexTokenizerStruct, Tokenizer, Trainable};

const TEST_ROUNDS: u32 = 10;
const WARMUP_ROUNDS: u32 = 2;
const VOCAB_SIZE: i32 = 512;

/// Anchor paths to this crate rather than the working directory, so the
/// benchmark can be run from anywhere. CARGO_MANIFEST_DIR is benchmarks/rs.
const CORPUS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/taylorswift.txt");
const RESULTS: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../benchmarks/results/rust.json"
);

/// Time train/encode/decode, averaged over `TEST_ROUNDS` timed rounds.
///
/// Every training round runs on a freshly constructed tokenizer, matching the
/// Mojo and Python benchmarks: `train` accumulates merges rather than
/// replacing them, so reusing one tokenizer would skew the results.
/// Construction sits outside the timed region.
fn benchmark<T, F>(make: F, text: &str) -> [f64; 3]
where
    T: Tokenizer + Trainable,
    F: Fn() -> T,
{
    for _ in 0..WARMUP_ROUNDS {
        let mut tokenizer = make();
        tokenizer.train(text, VOCAB_SIZE, false);
        let warm = tokenizer.encode(text);
        std::hint::black_box(tokenizer.decode(&warm));
    }

    let mut tokenizer = make();
    let mut t1 = Duration::ZERO;
    for _ in 0..TEST_ROUNDS {
        tokenizer = make();
        let s1 = Instant::now();
        tokenizer.train(text, VOCAB_SIZE, false);
        t1 += s1.elapsed();
    }

    let mut encoded = Vec::new();
    let mut t2 = Duration::ZERO;
    for _ in 0..TEST_ROUNDS {
        let s2 = Instant::now();
        encoded = tokenizer.encode(text);
        t2 += s2.elapsed();
    }

    let mut t3 = Duration::ZERO;
    for _ in 0..TEST_ROUNDS {
        let s3 = Instant::now();
        std::hint::black_box(tokenizer.decode(&encoded));
        t3 += s3.elapsed();
    }

    let rounds = f64::from(TEST_ROUNDS);
    [
        t1.as_secs_f64() / rounds,
        t2.as_secs_f64() / rounds,
        t3.as_secs_f64() / rounds,
    ]
}

fn print_result(name: &str, r: &[f64; 3]) {
    println!("-------------------------------------------------------------");
    println!("Benchmark results for {name}\n");
    println!("Average training time: {} seconds", r[0]);
    println!("Average encoding time: {} seconds", r[1]);
    println!("Average decoding time: {} seconds\n", r[2]);
    println!("Sum: {} seconds", r.iter().sum::<f64>());
    println!("-------------------------------------------------------------");
}

fn json_block(name: &str, r: &[f64; 3]) -> String {
    format!(
        "\t\"{}\": {{\n\t\t\"training_time\": {},\n\t\t\"encoding_time\": {},\n\
         \t\t\"decoding_time\": {},\n\t\t\"total_time\": {}\n\t}},\n",
        name,
        r[0],
        r[1],
        r[2],
        r.iter().sum::<f64>()
    )
}

fn main() {
    let text = fs::read_to_string(CORPUS)
        .unwrap_or_else(|e| panic!("cannot read {CORPUS}: {e}"));

    println!("Benchmarking: {TEST_ROUNDS} timed rounds after {WARMUP_ROUNDS} warmup rounds\n");

    let r1 = benchmark(BasicTokenizer::new, &text);
    print_result("Basic Tokenizer", &r1);

    let r2 = benchmark(RegexTokenizerStruct::default, &text);
    print_result("Regex Tokenizer", &r2);

    let overall = r1.iter().sum::<f64>() + r2.iter().sum::<f64>();
    println!("\nTotal average time: {overall} seconds\n");

    let json = format!(
        "{{\n{}{}\t\"overall_total_time\":{}\n}}",
        json_block("basic", &r1),
        json_block("regex", &r2),
        overall
    );
    fs::write(RESULTS, json).expect("cannot write results_rust.json");
}
