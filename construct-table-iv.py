import pandas as pd

df = pd.read_csv("results1.csv")
fails_df = df[df['Result'] == 'Fail']
fail_counts = fails_df.groupby(['Program', 'Technique', 'TimePerClass']).size().reset_index(name='FailCount')

print(fail_counts)
fail_counts.to_csv("fail_counts1.csv", index=False)
