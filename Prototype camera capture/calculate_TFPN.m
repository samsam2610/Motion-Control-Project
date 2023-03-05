function [TP, FP, TN, FN , accuracy, precision, recall, F1, specificity] = calculate_TFPN(data)
    data_length = size(data, 1);
    TP = 0;
    FP = 0;
    TN = 0;
    FN = 0;
    for indexData = 1:data_length
        data_unit = data(indexData, :);
        if data_unit(1) == 1 && data_unit(2) == 1
            TP = TP + 1;
        elseif data_unit(1) == 1 && data_unit(2) == 0
            FP = FP + 1;
        elseif data_unit(1) == 0 && data_unit(2) == 0
            TN = TN + 1;
        elseif data_unit(1) == 0 && data_unit(2) == 1
            FN = FN + 1;
        end
    end
    accuracy = (TP + TN)/(TP+FP+TN+FN);
    precision = (TP)/(TP+FP);
    recall = TP/(TP+FN);
    F1 = 2*(recall*precision)/(recall+precision);
    specificity = TN/(TN+FP);
end

