
from time import now

from mojobpe import Tokenizer,BasicTokenizationStrategy,RegexTokenizationStrategy
from mojobpe.standards import GPT4_SPLIT_PATTERN,GPT4_SPECIAL_TOKENS
from mojobpe.utils.tat import print_list_int

alias TEST_ROUNDS = 1
alias VERBOSE = False

fn benchmark(inout tokenizer:Tokenizer,text:String,test_rounds:Int) raises -> List[Float32]:
   
    var s1 = now()
    for i in range(test_rounds):
        tokenizer.train(text,512,VERBOSE)
       
    var e1 = (now() - s1)/test_rounds
    
    var s2=now()
    var encoded = List[Int]()
    for i in range(test_rounds):
        encoded = tokenizer.encode(text)
    var e2 = (now() - s2)/test_rounds
   
    var s3=now()
    var decoded:String = ""
    for i in range(test_rounds):
        decoded = tokenizer.decode(encoded)
    
    var e3 = (now() - s3)/test_rounds

    _ = decoded

    return List[Float32](e1,e2,e3)

fn print_result(name:String,r:List[Float32]):
    
    print("-------------------------------------------------------------")
    print("Benchmark results for",name,"\n")
    print("Average training time: " + str(r[0] / 1_000_000_000) + " seconds")
    print("Average encoding time: " + str(r[1] / 1_000_000_000) + " seconds")
    print("Average decoding time: " + str(r[2] / 1_000_000_000) + " seconds\n")
    print("Sum: " + str((r[0]+r[1]+r[2]) / 1_000_000_000) + " seconds")
    print("-------------------------------------------------------------")
   
fn json_block(name:String,data:List[Float32]) ->String:
    var total = (data[0] + data[1] + data[2])/1_000_000_000
    var res:String = ""
    res += "\t\"" + name+ "\": {\n"
    res += "\t\t\"training_time\": " + str(data[0]/1_000_000_000) + ",\n"
    res += "\t\t\"encoding_time\": " + str(data[1]/1_000_000_000) + ",\n"
    res += "\t\t\"decoding_time\": " + str(data[2]/1_000_000_000) + ",\n"
    res += "\t\t\"total_time\": " + str(total) + "\n"
    res += "\t},\n"
    return res



fn write_json(r1:List[Float32],r2:List[Float32]) raises:
    var ott = (r1[0] + r1[1] + r1[2] + r2[0] + r2[1] + r2[2])/1_000_000_000
    with open("results_mojo.json", 'w') as f:
        f.write("{\n")
        f.write(json_block("basic",r1))
        f.write(json_block("regex",r2))
        f.write("\t\"overall_total_time\":" + str(ott))
        f.write("\n}")
        

fn main() raises:

    var text = open("tests/taylorswift.txt", "r").read()

    var tokenizer = Tokenizer[BasicTokenizationStrategy]()
    var tokenizer2 = Tokenizer[RegexTokenizationStrategy[GPT4_SPLIT_PATTERN]]()
    
    var r1 = benchmark(tokenizer,text,TEST_ROUNDS)
    print_result("Basic Tokenizer",r1)

    var r2 = benchmark(tokenizer2,text,TEST_ROUNDS)
    print_result("Regex Tokenizer",r2)

    print("\nTotal average time: "+ str((r1[0]+r1[1]+r1[2]+ r2[0]+r2[1]+r2[2]) / 1_000_000_000) + " seconds\n")

    write_json(r1,r2)



    
    