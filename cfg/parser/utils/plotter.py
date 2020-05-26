
def plotter(experiment_name, data):
    try:
        import matplotlib
        matplotlib.use('Agg')
        from matplotlib import pyplot as plt
        import numpy as np
    except ModuleNotFoundError:
        return

    # Plot data
    x_label, y_label = data.keys()
    x, y = data[x_label], data[y_label]
    plt.plot(x, y, alpha=.25)
    plt.scatter(x, y, alpha=.5)

    # Plot ideal
    x_min, x_max = min(x), max(x)

    def ideal_speed(cores):
        return y[0]/x[0] * cores

    ideal_range = np.arange(x_min, x_max, 1)
    ideal_speed = [ideal_speed(_x) for _x in ideal_range]
    plt.plot(ideal_range, ideal_speed, ":", alpha=.25, color="k")

    # Format stuff
    plt.title(experiment_name)
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.yscale("log")
    plt.xscale("log")
    ax = plt.gca()
    ax.spines['right'].set_visible(False)
    ax.spines['top'].set_visible(False)

    # Only show ticks on the left and bottom spines
    ax.yaxis.set_ticks_position('left')
    ax.xaxis.set_ticks_position('bottom')

    filename = experiment_name + ".png"
    plt.savefig(filename)