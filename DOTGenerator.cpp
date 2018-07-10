//=======================================================================
// Copyright 2018 University of South Carolina.
// Authors: Chrisogonas O. Mc'Odhiambo
//
// Distributed under the Boost Software License, Version 1.0. (See
// accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)

// This simple program helps one to visualize OpenMPdirectives and clauses
// parsed in a program. It takes an input of directives and corresponding 
// clauses (as well as clauses attributes and attribute values with a bit
// of modification) and produces a graphical view of the same
//=======================================================================

#include <boost/graph/graphviz.hpp>

#include <boost/graph/graph_as_tree.hpp>
#include <boost/graph/adjacency_list.hpp>
#include <boost/cstdlib.hpp>
#include <iostream>
#include <string>
#include <fstream>

class tree_printer {
public:
	template <typename Node, typename Tree>
	void preorder(Node, Tree&) {
		std::cout << "(";
	}
	template <typename Node, typename Tree>
	void inorder(Node n, Tree& t)
	{
		std::cout << get(boost::vertex_name, t)[n];
	}

	template <typename Node, typename Tree>
	void postorder(Node, Tree&) {
		std::cout << ")";
	}

};

// test input details
//
// main program label
std::string mainProgram = "MainProgram";

// passed directives
std::string directives[] = { "parallel", "single", "concurrent" }; 

// corresponding clauses count for each directive
int clausesCount[] = { 5,4,4 };

// corresponding clauses
std::string clauses[] = { "private", "allocate", "sections", "shared", "reduction",
	"firstprivate", "copyprivate", "nowait", "allocate",
	"firstprivate", "private", "reduction", "levels"
};

int main()
{
	using namespace boost;
	typedef adjacency_list<vecS, vecS, directedS,
		property<vertex_name_t, std::string> > graph_t;
	typedef graph_traits<graph_t>::vertex_descriptor vertex_t;

	std::string filename = "TestFile.dot";
	std::ofstream fout(filename.c_str());

	graph_t g;

	int directivesLength = *(&directives + 1) - directives;
	int clausesLength = *(&clauses + 1) - clauses;

	//add vertices
	//
	add_vertex(g); // main program

	// directives vertices
	for (size_t i = 0; i < directivesLength; i++)
	{
		add_vertex(g);
	}

	// clause vertices
	for (size_t i = 0; i < clausesLength; i++)
	{
		add_vertex(g);
	}

	// Edges
	//
	// directive edges
	int totalClauses = 0;
	int startPoint = 0;
	int endPoint = 0;
	for (size_t i = 1; i <= directivesLength; i++)
	{
		add_edge(0, i, g);
	}

	// clauses edges
	int edgeId = directivesLength;
	totalClauses = 0;

	for (size_t i = 1; i <= directivesLength; i++)
	{
		int length = clausesCount[totalClauses];
		for (size_t c = 0; c < length; c++)
		{
			edgeId++;
			add_edge(i, edgeId, g);
		}
		totalClauses++;
	}

	// vertex properties
	// we can have other details here like attributes and values to clauses
	//
	typedef property_map<graph_t, vertex_name_t>::type vertex_name_map_t;
	vertex_name_map_t name = get(vertex_name, g);

	// program label
	name[0] = mainProgram;
	int counter = 0;

	// directive labels
	for (size_t i = 1; i <= directivesLength; i++)
	{
		name[i] = *(directives + counter);
		counter++;
	}

	// clauses labels
	edgeId = directivesLength;
	totalClauses = 0;

	for (size_t i = 1; i <= directivesLength; i++)
	{
		int length = clausesCount[totalClauses];
		for (size_t c = 0; c < length; c++)
		{
			edgeId++;
			name[edgeId] = *(clauses + c);
		}
		totalClauses++;
	}

	typedef iterator_property_map<std::vector<vertex_t>::iterator,
		property_map<graph_t, vertex_index_t>::type> parent_map_t;
	std::vector<vertex_t> parent(num_vertices(g));
	typedef graph_as_tree<graph_t, parent_map_t> tree_t;
	tree_t t(g, 0, make_iterator_property_map(parent.begin(),
		get(vertex_index, g)));

	tree_printer vis;
	traverse_tree(0, t, vis);

	boost::write_graphviz(fout, g); // save to file

	printf("\n");
	write_graphviz(std::cout, g, make_label_writer(name)); // print to screen

	return exit_success;
}


