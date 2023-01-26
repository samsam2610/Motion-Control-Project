q11 = parallel.pool.PollableDataQueue;
p = gcp;
f(1) = parfeval(@termin, 1, q11);
pause(0.5)
q2 = poll(q11);

send(q2, 0);
pause(5)
send(q2, 1);

function test = termin(q11)

    q2 = parallel.pool.PollableDataQueue; 
    send(q11, q2);
    while (1)
        [value, ~] = poll(q2);
        if value == 1
            test = true;
            break
        end
    end
end
