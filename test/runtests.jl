
using Compat
using Requests
using JSON
using FactCheck
using Base.Test


facts("Simple calls with no params") do
  for method in [get, put, post, delete]
    url = "http://httpbin.org/$method"
    println(uppercase("$method ") * url)
    res = method(url)
    @fact res.status => 200
  end
end

qstring(method, query) =
  "$(uppercase(string(method))) $(Requests.format_query_str(query))"

facts("Query Parameters") do
  query = @compat Dict("key1" => "value1",
                       "key4" => 4.01,
                       "key with spaces" => "value with spaces")
  for method in [get, put, post, delete]
    data = JSON.parse(method("http://httpbin.org/$method"; query = query).data)
    println(qstring(method, query))
    @fact data["args"]["key1"] => "value1"
    @fact data["args"]["key4"] => "4.01"
    @fact data["args"]["key with spaces"] => "value with spaces"
  end
end

facts("JSON Data") do
  js = @compat Dict("key1" => "value1",
    "key2" => "value2",
    "key3" => 3)
  for method in [put, post, delete]
    print(JSON.json(js, 4))
    data = JSON.parse(method("http://httpbin.org/$method"; json = js).data)
    @fact data["json"]["key1"] => "value1"
    @fact data["json"]["key2"] => "value2"
    @fact data["json"]["key3"] => 3
  end
end

facts("JSON with Query Params") do
  query = (@compat Dict("qkey1" => "value1",
                        "qkey2" => "value2",
                        "qkey3" => 3))
  js = @compat Dict("dkey1" => "data1",
                    "dkey2" => "data2",
                    "dkey3" => 5)
  for method in [put, post, delete]
    data = JSON.parse(put("http://httpbin.org/put";
                          query = query,
                          json = js).data)

    println(qstring(method, query))
    print(JSON.json(js, 4))

    @fact data["args"]["qkey1"] => "value1"
    @fact data["args"]["qkey2"] => "value2"
    @fact data["args"]["qkey3"] => "3"
    @fact data["json"]["dkey1"] => "data1"
    @fact data["json"]["dkey2"] => "data2"
    @fact data["json"]["dkey3"] => 5
  end
end

facts("Plain Text") do
  data = JSON.parse(post(URI("http://httpbin.org/post");
                       data = "√",
                       headers = @compat Dict("Content-Type" => "text/plain")).data)
  @fact data["data"] => "√"
end
# Test file upload
filename = Base.source_path()

files = [
  FileParam(readall(filename),"text/julia","file1","runtests.jl"),
  FileParam(open(filename,"r"),"text/julia","file2","runtests.jl",true),
  FileParam(IOBuffer(readall(filename)),"text/julia","file4","runtests.jl"),
  ]

# Does not work on 0.2, because mmap can't be used on Base.File
# if VERSION >= v"0.3-"
#     push!(files,FileParam(Base.File(filename),"text/julia","file3","runtests.jl"))
# end

# # Currently causing build to hang in 0.4
# res = post(URI("http://httpbin.org/post"); files = files)
#
# filecontent = readall(filename)
# data = JSON.parse(res.data)
# @test data["files"]["file1"] == filecontent
# @test data["files"]["file2"] == filecontent
# if VERSION >= v"0.3-"
#     @test data["files"]["file3"] == filecontent
# end
# @test data["files"]["file4"] == filecontent

# Test for chunked responses (we expect 100 from split as there are 99 '\n')
facts("Chunked Response") do
  @fact size(split(get("http://httpbin.org/stream/99").data, "\n"), 1) => 100
end
