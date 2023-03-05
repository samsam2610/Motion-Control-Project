v = VideoReader('E:\zhong\cam2_Xavier_2023-02-21_200f-8e100g1.avi');
%%
timestamp2 = readmatrix('E:\zhong\TIMESTAMPS_cam2.csv');
timediff2 = diff(timestamp2);