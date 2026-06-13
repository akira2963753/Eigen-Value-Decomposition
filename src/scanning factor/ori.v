module ori();
    reg signed [17:0] a, b;
    wire signed [18:0] result;

    assign result = a | b;

    initial begin
        a = 18'sb10101010_10101010_10; // Example value for a
        b = 18'sb01010101_01010101_01; // Example value for b

        #10; // Wait for 10 time units
        $display("a: %b", a);
        $display("b: %b", b);
        $display("result (a | b): %b", result);
    end
endmodule